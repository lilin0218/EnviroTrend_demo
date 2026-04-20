#include "coremanager.h"
#include "logger.h"
#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFile>
#include <QCoreApplication>

CoreManager::CoreManager(QObject *parent) : QObject(parent),
    m_backstage(Backstage::instance()),
    m_networkManager(NetworkManager::instance()),
    m_dht11(new DHT11(this)),
    m_lightSensor(new LightSensor(this)),
    m_zpSensor(new ZPSensor(this)),
    m_mq135Sensor(new MQ135Sensor(this)),
    m_predictProcess(new QProcess(this)),
    m_baseTime(0),
    m_isAiBusy(false)
{
    Logger::instance()->info("CORE", "CoreManager initialized");
    
    connect(m_backstage, &Backstage::errorOccurred, this, &CoreManager::handleBackstageError);
    
    connect(m_dht11, &DHT11::valueSig, m_backstage, &Backstage::handleDHT11);
    connect(m_lightSensor, &LightSensor::valueSig, m_backstage, &Backstage::handleLight);
    connect(m_zpSensor, &ZPSensor::valueSig, m_backstage, &Backstage::handleZP);
    connect(m_mq135Sensor, &MQ135Sensor::valueSig, m_backstage, &Backstage::handleMQ135);
    
    connect(m_backstage, &Backstage::valueSig, this, &CoreManager::onBackstageDataChanged);
    connect(m_backstage, &Backstage::bufferSig, this, &CoreManager::bufferSig);
    
    connect(m_dht11, &DHT11::errorOccurred, this, &CoreManager::handleSensorError);
    connect(m_lightSensor, &LightSensor::errorOccurred, this, &CoreManager::handleSensorError);
    connect(m_zpSensor, &ZPSensor::errorOccurred, this, &CoreManager::handleSensorError);
    connect(m_mq135Sensor, &MQ135Sensor::errorOccurred, this, &CoreManager::handleSensorError);
    
    // 连接网络状态信号
    connect(m_networkManager, &NetworkManager::connectionStatusChanged, this, &CoreManager::networkStatusChanged);
    
    // 连接日志信号
    connect(Logger::instance(), &Logger::logAdded, this, &CoreManager::handleLogAdded);
    
    // 加载已有的日志历史
    QList<QVariantMap> history = Logger::instance()->getLogHistory();
    for (const QVariantMap& entry : history) {
        m_logList.append(entry);
    }
    emit logListUpdated();

    m_dht11->start();
    m_lightSensor->start();
    m_zpSensor->start();
    m_mq135Sensor->start();

    // 等待DHT11初始化完成，然后设置模拟模式
    QTimer::singleShot(500, this, [this]() {
        bool isHardware = m_dht11->useHardware();
        m_backstage->setMockMode(!isHardware);
        qDebug() << "[CORE] Hardware mode:" << isHardware << "Mock mode:" << !isHardware;
        emit sensorStatusChanged();
    });

    // 预测进程初始化
    connect(m_predictProcess, &QProcess::readyReadStandardOutput, this, [this]() {
        m_aiStdoutBuffer.append(m_predictProcess->readAllStandardOutput());
    });

    connect(m_predictProcess, &QProcess::errorOccurred, this, &CoreManager::handleProcessError);

    connect(m_predictProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int exitCode, QProcess::ExitStatus exitStatus){
        Q_UNUSED(exitStatus);
        qDebug() << "[AI] Process finished. Exit code:" << exitCode
                 << "stdout bytes:" << m_aiStdoutBuffer.size();
        handleProcessOutput();
        m_aiStdoutBuffer.clear();
        m_isAiBusy = false;
        emit aiStatusChanged();
    });

    // 启动时尝试加载一次现有数据（触发QML绘图）
    QMetaObject::invokeMethod(this, "bufferSig", Qt::QueuedConnection);
}

CoreManager::~CoreManager() {
    if (m_predictProcess->state() == QProcess::Running) {
        m_predictProcess->kill();
        m_predictProcess->waitForFinished(1000);
    }
    
    delete m_dht11;
    delete m_lightSensor;
    delete m_zpSensor;
    delete m_mq135Sensor;
}

void CoreManager::runPrediction() {
    if (m_isAiBusy || m_predictProcess->state() != QProcess::NotRunning) {
        Logger::instance()->warning("AI", QString("Prediction request ignored. busy: %1, state: %2")
                                   .arg(m_isAiBusy).arg(m_predictProcess->state()));
        emit errorOccurred("Prediction is already running");
        return;
    }

    QString scriptPath = QCoreApplication::applicationDirPath() + "/predict.py";
    if (!QFile::exists(scriptPath)) {
        Logger::instance()->error("AI", "Prediction script not found: " + scriptPath);
        emit errorOccurred("Prediction script not found");
        return;
    }

    m_baseTime = QDateTime::currentMSecsSinceEpoch();

    m_isAiBusy = true;
    emit aiStatusChanged();

    QStringList args;
    args << scriptPath << "1440" << "60";

    Logger::instance()->info("AI", QString("Starting prediction. args: %1").arg(args.join(", ")));
    m_predictProcess->start("python3", args);
    if (!m_predictProcess->waitForStarted(2000)) {
        Logger::instance()->error("AI", "Failed to start prediction process");
        m_isAiBusy = false;
        emit aiStatusChanged();
        emit errorOccurred("Failed to start prediction process");
    }
    Logger::instance()->info("AI", QString("Prediction started, baseTime locked at: %1").arg(m_baseTime));
}

void CoreManager::clearHistoryBuffer() {
    Logger::instance()->info("CORE", "Midnight reset triggered");
    m_backstage->clearTempBuffer();
    m_backstage->clearHumBuffer();
    emit bufferSig();
}

void CoreManager::handleProcessOutput() {
    QByteArray rawOutput = m_aiStdoutBuffer.trimmed();
    Logger::instance()->debug("AI", QString("Stdout length: %1 bytes").arg(rawOutput.size()));

    if (rawOutput.isEmpty()) {
        Logger::instance()->warning("AI", "Stdout is empty. No data received.");
        emit errorOccurred("No prediction data received");
        return;
    }

    int jsonStartIndex = rawOutput.indexOf("[{");
    if (jsonStartIndex == -1) {
        Logger::instance()->warning("AI", "No JSON prefix '[{' found in stdout");
        emit errorOccurred("Invalid prediction data format");
        return;
    }

    QByteArray cleanJson = rawOutput.mid(jsonStartIndex);
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(cleanJson, &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        Logger::instance()->error("AI", QString("JSON parse error: %1").arg(parseError.errorString()));
        emit errorOccurred("Failed to parse prediction data");
        return;
    }

    if (!doc.isNull() && doc.isArray()) {
        QJsonArray arr = doc.array();
        m_predictedTempList.clear();
        m_predictedHumList.clear();

        for (int i = 0; i < arr.size(); ++i) {
            QJsonObject obj = arr[i].toObject();
            m_predictedTempList << obj["temp"].toDouble();
            m_predictedHumList << obj["hum"].toDouble();
        }

        emit predictionUpdated();
        Logger::instance()->info("AI", QString("24H Prediction updated. Data points: %1").arg(m_predictedTempList.size()));
    } else {
        Logger::instance()->warning("AI", "Invalid JSON format: not an array");
        emit errorOccurred("Invalid prediction data format");
    }
}

void CoreManager::handleProcessError(QProcess::ProcessError error) {
    Logger::instance()->error("AI", QString("Process error: %1").arg(static_cast<int>(error)));
    m_isAiBusy = false;
    emit aiStatusChanged();
    emit errorOccurred("Prediction process error");
}

void CoreManager::handleSensorError(const QString &error) {
    Logger::instance()->warning("SENSOR", error);
    emit errorOccurred("Sensor error: " + error);
}

void CoreManager::handleBackstageError(const QString &error) {
    Logger::instance()->critical("BACKSTAGE", error);
    emit errorOccurred(error);
}

// 基础接口
QString CoreManager::tempStr() const {
    return QString::number(m_backstage->getTemp(), 'f', 1);
}

QString CoreManager::humStr() const {
    return QString::number(m_backstage->getHum(), 'f', 1);
}

QString CoreManager::lightStr() const {
    return QString::number(m_backstage->getLight(), 'f', 2);
}

QString CoreManager::pm25Str() const {
    return QString::number(m_backstage->getPM25(), 'f', 1);
}

QString CoreManager::pm10Str() const {
    return QString::number(m_backstage->getPM10(), 'f', 1);
}

QString CoreManager::aqiStr() const {
    return QString::number(m_backstage->getAQI(), 'f', 1);
}

QList<double> CoreManager::tempBuffer() const {
    return m_backstage->getTempBuffer();
}

QList<double> CoreManager::humBuffer() const {
    return m_backstage->getHumBuffer();
}

QList<double> CoreManager::lightBuffer() const {
    return m_backstage->getLightBuffer();
}

QList<double> CoreManager::pm25Buffer() const {
    return m_backstage->getPM25Buffer();
}

QList<double> CoreManager::pm10Buffer() const {
    return m_backstage->getPM10Buffer();
}

QList<double> CoreManager::aqiBuffer() const {
    return m_backstage->getAQIBuffer();
}

QVariantList CoreManager::predictedTempList() const {
    return m_predictedTempList;
}

QVariantList CoreManager::predictedHumList() const {
    return m_predictedHumList;
}

qint64 CoreManager::baseTime() const {
    return m_baseTime;
}

bool CoreManager::isAiBusy() const {
    return m_isAiBusy;
}

bool CoreManager::isSensorActive() const {
    return m_dht11->getActive();
}

bool CoreManager::isNetworkConnected() const {
    return m_networkManager->isConnected();
}

int CoreManager::getMsPerPoint() const {
    return m_backstage->getMsPerPoint();
}

void CoreManager::onBackstageDataChanged() {
    emit valueSig();
}

void CoreManager::setSensorActive(int id, bool active) {
    switch (id) {
    case 0:
        m_dht11->setActive(active);
        break;
    case 1:
        m_lightSensor->setActive(active);
        break;
    case 2:
        m_zpSensor->setActive(active);
        break;
    case 3:
        m_mq135Sensor->setActive(active);
        break;
    default:
        break;
    }
    emit sensorStatusChanged();
    emit sensorSig(id);
}

void CoreManager::setSensorInterval(int id, int sec) {
    switch (id) {
    case 0:
        m_dht11->setInterval(sec * 1000); // 转换为毫秒
        break;
    case 1:
        m_lightSensor->setInterval(sec * 1000);
        break;
    case 2:
        m_zpSensor->setInterval(sec * 1000);
        break;
    case 3:
        m_mq135Sensor->setInterval(sec * 1000);
        break;
    default:
        break;
    }
    emit sensorSig(id);
}

bool CoreManager::getSensorActive(int id) {
    switch (id) {
    case 0:
        return m_dht11->getActive();
    case 1:
        return m_lightSensor->getActive();
    case 2:
        return m_zpSensor->getActive();
    case 3:
        return m_mq135Sensor->getActive();
    default:
        return false;
    }
}

int CoreManager::getSensorInterval(int id) {
    switch (id) {
    case 0:
        return m_dht11->getInterval() / 1000; // 转换为秒
    case 1:
        return m_lightSensor->getInterval() / 1000;
    case 2:
        return m_zpSensor->getInterval() / 1000;
    case 3:
        return m_mq135Sensor->getInterval() / 1000;
    default:
        return -1;
    }
}

QVariantList CoreManager::logList() const {
    return m_logList;
}

void CoreManager::handleLogAdded(const QString& timestamp, const QString& level, const QString& module, const QString& message, const QString& color) {
    qDebug() << "[DEBUG CoreManager] handleLogAdded received - level:" << level << "module:" << module << "message:" << message;
    
    QVariantMap logEntry;
    logEntry["timestamp"] = timestamp;
    logEntry["level"] = level;
    logEntry["module"] = module;
    logEntry["message"] = message;
    logEntry["color"] = color;
    
    m_logList.append(logEntry);
    qDebug() << "[DEBUG CoreManager] logList size:" << m_logList.size();
    
    if (m_logList.size() > 100) {
        m_logList.removeFirst();
    }
    
    qDebug() << "[DEBUG CoreManager] Emitting logListUpdated";
    emit logListUpdated();
}
