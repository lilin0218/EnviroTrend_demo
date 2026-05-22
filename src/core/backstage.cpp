#include "backstage.h"
#include "logger.h"
#include "networkmanager.h"
#include <QCoreApplication>
#include <QJsonDocument>

Backstage::Backstage(QObject *parent)
    : QObject(parent),
      m_currentTemp(0.0),
      m_currentHum(0.0),
      m_currentLight(0.0),
      m_currentZP01(0.0),
      m_currentMQ135(0.0),
      MAX_POINTS_24H(1440),
      m_msPerPoint(60000),
      m_sampleStep(5),
      m_mockMode(false),
      m_networkManager(NetworkManager::instance()) {

    // 初始化存储 - 如果数据库不存在则报错
    if (!initStorage()) {
        // 数据库不存在，标记为未初始化状态
        m_dbPath.clear();
        return;
    }
    
    if (!initDatabase()) {
        emit errorOccurred("Failed to initialize database");
        return;
    }
    if (!loadBufferFromDatabase()) {
        emit errorOccurred("Failed to load buffer from database");
        return;
    }

    m_sampleTimer = new QTimer(this);
    connect(m_sampleTimer, &QTimer::timeout, this, &Backstage::processSnapshot);
    m_sampleTimer->start(m_msPerPoint);
}

Backstage::~Backstage() {
    if (m_sampleTimer->isActive()) {
        m_sampleTimer->stop();
        // 确保最后一次数据写入
        if (!m_mockMode) {
            updateDatabase(m_currentTemp, m_currentHum, m_currentLight, m_currentMQ135, m_currentZP01);
        }
    }
    if (m_db.isOpen()) {
        m_db.close();
    }
}

Backstage *Backstage::instance() {
    static Backstage _instance;
    return &_instance;
}

bool Backstage::initStorage() {
    QDir dir;
    QString appDir = QCoreApplication::applicationDirPath();
    QString dbDir = appDir + "/dbData";
    
    if (!dir.exists(dbDir)) {
        Logger::instance()->critical("DB", "Database directory does not exist: " + dbDir);
        emit errorOccurred("数据库目录不存在: " + dbDir + "\n请先运行 pull_db.sh 从开发板获取数据库");
        return false;
    }
    
    m_dbPath = dbDir + "/enviro_data.db";
    
    QFile dbFile(m_dbPath);
    if (!dbFile.exists()) {
        Logger::instance()->warning("DB", "Database file does not exist: " + m_dbPath + ", will create new database");
    }
    
    return true;
}

bool Backstage::initDatabase() {
    m_db = QSqlDatabase::addDatabase("QSQLITE");
    m_db.setDatabaseName(m_dbPath);

    if (!m_db.open()) {
        Logger::instance()->critical("DB", QString("Failed to open database: %1").arg(m_db.lastError().text()));
        return false;
    }

    QSqlQuery query(m_db);
    QString createTableSQL = 
        "CREATE TABLE IF NOT EXISTS sensor_data ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "timestamp DATETIME NOT NULL, "
        "temperature REAL, "
        "humidity REAL, "
        "light REAL, "
        "mq135 REAL, "
        "zp01 REAL"
        ")";

    if (!query.exec(createTableSQL)) {
        Logger::instance()->critical("DB", QString("Failed to create table: %1").arg(query.lastError().text()));
        return false;
    }

    QString createIndexSQL = "CREATE INDEX IF NOT EXISTS idx_timestamp ON sensor_data(timestamp)";
    if (!query.exec(createIndexSQL)) {
        Logger::instance()->warning("DB", QString("Failed to create index: %1").arg(query.lastError().text()));
    }

    Logger::instance()->info("DB", "Database initialized successfully at " + m_dbPath);
    return true;
}

bool Backstage::loadBufferFromDatabase() {
    if (!m_db.isOpen()) {
        Logger::instance()->warning("DB", "Database not open, cannot load buffer");
        return false;
    }

    QSqlQuery query(m_db);
    QString sql = QString(
        "SELECT temperature, humidity, light, mq135, zp01 FROM sensor_data "
        "ORDER BY timestamp DESC LIMIT %1"
    ).arg(MAX_POINTS_24H);

    if (!query.exec(sql)) {
        Logger::instance()->warning("DB", QString("Failed to load buffer: %1").arg(query.lastError().text()));
        return false;
    }

    m_tempBuffer.clear();
    m_humBuffer.clear();
    m_lightBuffer.clear();
    m_zp01Buffer.clear();
    m_mq135Buffer.clear();

    QList<QVariant> tempList, humList, lightList, mq135List, zp01List;
    while (query.next()) {
        // 使用 QVariant 保存，NULL值保持为无效的 QVariant
        QVariant tempVal = query.value(0);
        QVariant humVal = query.value(1);
        QVariant lightVal = query.value(2);
        QVariant mq135Val = query.value(3);
        QVariant zp01Val = query.value(4);
        
        // 如果是 NULL，使用 NaN 标记
        tempList.prepend(tempVal.isNull() ? QVariant(qQNaN()) : tempVal.toDouble());
        humList.prepend(humVal.isNull() ? QVariant(qQNaN()) : humVal.toDouble());
        lightList.prepend(lightVal.isNull() ? QVariant(qQNaN()) : lightVal.toDouble());
        mq135List.prepend(mq135Val.isNull() ? QVariant(qQNaN()) : mq135Val.toDouble());
        zp01List.prepend(zp01Val.isNull() ? QVariant(qQNaN()) : zp01Val.toDouble());
    }

    m_tempBuffer = tempList;
    m_humBuffer = humList;
    m_lightBuffer = lightList;
    m_mq135Buffer = mq135List;
    m_zp01Buffer = zp01List;

    Logger::instance()->debug("DB", QString("Loaded %1 records from database").arg(m_tempBuffer.size()));
    return true;
}

bool Backstage::updateDatabase(double t, double h, double light, double mq135, double zp01) {
    if (!m_db.isOpen()) {
        Logger::instance()->warning("DB", "Database not open, cannot update");
        return false;
    }

    QSqlQuery query(m_db);
    
    // 插入新数据
    query.prepare(
        "INSERT INTO sensor_data (timestamp, temperature, humidity, light, mq135, zp01) "
        "VALUES (:timestamp, :temperature, :humidity, :light, :mq135, :zp01)"
    );

    QString now = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss");
    query.bindValue(":timestamp", now);
    query.bindValue(":temperature", t);
    query.bindValue(":humidity", h);
    query.bindValue(":light", light);
    query.bindValue(":mq135", mq135);
    query.bindValue(":zp01", zp01);

    if (!query.exec()) {
        Logger::instance()->error("DB", QString("Failed to insert data: %1").arg(query.lastError().text()));
        return false;
    }
    
    // 删除超过1周的老数据
    QSqlQuery deleteQuery(m_db);
    QString deleteSQL = "DELETE FROM sensor_data WHERE timestamp < datetime('now', '-7 days')";
    if (!deleteQuery.exec(deleteSQL)) {
        Logger::instance()->warning("DB", QString("Failed to delete old data: %1").arg(deleteQuery.lastError().text()));
    } else if (deleteQuery.numRowsAffected() > 0) {
        Logger::instance()->debug("DB", QString("Deleted %1 old records (older than 7 days)").arg(deleteQuery.numRowsAffected()));
    }
    
    return true;
}

void Backstage::processSnapshot() {
    auto updateBuf = [this](QList<QVariant> &list, double val) {
        list.append(val);
        if (list.size() > MAX_POINTS_24H) {
            list.removeFirst();
        }
    };

    updateBuf(m_tempBuffer, m_currentTemp);
    updateBuf(m_humBuffer, m_currentHum);
    updateBuf(m_lightBuffer, m_currentLight);
    updateBuf(m_zp01Buffer, m_currentZP01);
    updateBuf(m_mq135Buffer, m_currentMQ135);

    // 只有在非模拟模式下才写入数据库和上传到服务器
    if (!m_mockMode) {
        updateDatabase(m_currentTemp, m_currentHum, m_currentLight, m_currentMQ135, m_currentZP01);
        uploadToServer();
    }

    emit bufferSig();
}

void Backstage::uploadToServer() {
    QJsonObject data;
    data["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    data["temperature"] = m_currentTemp;
    data["humidity"] = m_currentHum;
    data["light"] = m_currentLight;
    data["mq135"] = m_currentMQ135;
    data["zp01"] = m_currentZP01;

    Logger::instance()->info("UPLOAD", "Preparing to upload sensor data to server");
    m_networkManager->uploadData(data);
}

// --- Getter / Setter ---

double Backstage::getTemp() const {
    return m_currentTemp;
}

double Backstage::getHum() const {
    return m_currentHum;
}

double Backstage::getLight() const {
    return m_currentLight;
}

double Backstage::getZP01() const {
    return m_currentZP01;
}

double Backstage::getMQ135() const {
    return m_currentMQ135;
}

void Backstage::setTemp(double temp) {
    m_currentTemp = temp;
}

void Backstage::setHum(double hum) {
    m_currentHum = hum;
}

void Backstage::setLight(double light) {
    m_currentLight = light;
}

void Backstage::setZP01(double zp01) {
    m_currentZP01 = zp01;
}

void Backstage::setMQ135(double mq135) {
    m_currentMQ135 = mq135;
}

QList<QVariant> Backstage::getTempBuffer() const {
    return m_tempBuffer;
}

QList<QVariant> Backstage::getHumBuffer() const {
    return m_humBuffer;
}

QList<QVariant> Backstage::getLightBuffer() const {
    return m_lightBuffer;
}

QList<QVariant> Backstage::getZP01Buffer() const {
    return m_zp01Buffer;
}

QList<QVariant> Backstage::getMQ135Buffer() const {
    return m_mq135Buffer;
}

int Backstage::getMsPerPoint() const {
    return m_msPerPoint;
}

void Backstage::setMockMode(bool mockMode) {
    m_mockMode = mockMode;
    Logger::instance()->info("DB", QString("Mock mode set to: %1").arg(mockMode));
}

bool Backstage::isMockMode() const {
    return m_mockMode;
}

bool Backstage::isDatabaseOpen() const {
    return m_db.isOpen();
}

bool Backstage::purgeOldData(int daysToKeep) {
    if (!m_db.isOpen()) {
        Logger::instance()->warning("DB", "Database not open, cannot purge old data");
        return false;
    }

    QSqlQuery query(m_db);
    QString sql = QString(
        "DELETE FROM sensor_data WHERE timestamp < datetime('now', '-%1 days')"
    ).arg(daysToKeep);

    if (!query.exec(sql)) {
        Logger::instance()->error("DB", QString("Failed to purge old data: %1").arg(query.lastError().text()));
        return false;
    }

    Logger::instance()->info("DB", QString("Purged old data, rows affected: %1").arg(query.numRowsAffected()));
    return true;
}

void Backstage::clearTempBuffer() {
    m_tempBuffer.clear();
}

void Backstage::clearHumBuffer() {
    m_humBuffer.clear();
}

void Backstage::clearLightBuffer() {
    m_lightBuffer.clear();
    
    if (m_db.isOpen()) {
        QSqlQuery query(m_db);
        if (!query.exec("UPDATE sensor_data SET light = NULL")) {
            Logger::instance()->warning("DB", QString("Failed to clear light in database: %1").arg(query.lastError().text()));
        }
    }
}

void Backstage::clearZP01Buffer() {
    m_zp01Buffer.clear();
    
    if (m_db.isOpen()) {
        QSqlQuery query(m_db);
        if (!query.exec("UPDATE sensor_data SET zp01 = NULL")) {
            Logger::instance()->warning("DB", QString("Failed to clear zp01 in database: %1").arg(query.lastError().text()));
        }
    }
}

void Backstage::clearMQ135Buffer() {
    m_mq135Buffer.clear();
    
    if (m_db.isOpen()) {
        QSqlQuery query(m_db);
        if (!query.exec("UPDATE sensor_data SET mq135 = NULL")) {
            Logger::instance()->warning("DB", QString("Failed to clear mq135 in database: %1").arg(query.lastError().text()));
        }
    }
}

void Backstage::clearAllBuffers() {
    clearTempBuffer();
    clearHumBuffer();
    clearLightBuffer();
    clearZP01Buffer();
    clearMQ135Buffer();
    emit bufferSig();
}

void Backstage::handleDHT11(const QVariantMap &data) {
    if (data.contains("temperature")) {
        setTemp(data["temperature"].toDouble());
    }
    if (data.contains("humidity")) {
        setHum(data["humidity"].toDouble());
    }
    emit valueSig();
}

void Backstage::handleLight(const QVariantMap &data) {
    if (data.contains("light")) {
        setLight(data["light"].toDouble());
    }
    emit valueSig();
}

void Backstage::handleZP(const QVariantMap &data) {
    if (data.contains("zp01")) {
        setZP01(data["zp01"].toDouble());
    }
    emit valueSig();
}

void Backstage::handleMQ135(const QVariantMap &data) {
    if (data.contains("mq135")) {
        setMQ135(data["mq135"].toDouble());
    }
    emit valueSig();
}

int Backstage::getSampleStep() const {
    return m_sampleStep;
}

QVariantList Backstage::getSampledTempBuffer() const {
    QVariantList result;
    for (int i = 0; i < m_tempBuffer.size(); i += m_sampleStep) {
        result.append(m_tempBuffer.at(i));
    }
    return result;
}

QVariantList Backstage::getSampledHumBuffer() const {
    QVariantList result;
    for (int i = 0; i < m_humBuffer.size(); i += m_sampleStep) {
        result.append(m_humBuffer.at(i));
    }
    return result;
}

QVariantList Backstage::getSampledLightBuffer() const {
    QVariantList result;
    for (int i = 0; i < m_lightBuffer.size(); i += m_sampleStep) {
        result.append(m_lightBuffer.at(i));
    }
    return result;
}

QVariantList Backstage::getSampledZp01Buffer() const {
    QVariantList result;
    for (int i = 0; i < m_zp01Buffer.size(); i += m_sampleStep) {
        result.append(m_zp01Buffer.at(i));
    }
    return result;
}

QVariantList Backstage::getSampledMq135Buffer() const {
    QVariantList result;
    for (int i = 0; i < m_mq135Buffer.size(); i += m_sampleStep) {
        result.append(m_mq135Buffer.at(i));
    }
    return result;
}
