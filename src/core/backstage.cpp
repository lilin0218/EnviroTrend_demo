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
      m_currentPM25(0.0),
      m_currentPM10(0.0),
      m_currentAQI(0.0),
      m_currentGas(0.0),
      MAX_POINTS_24H(1440),
      m_msPerPoint(60000),
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
            updateDatabase(m_currentTemp, m_currentHum, m_currentLight, m_currentPM25, m_currentPM10, m_currentAQI);
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
        "temp REAL, "
        "hum REAL, "
        "light REAL, "
        "pm25 REAL, "
        "pm10 REAL, "
        "aqi REAL, "
        "noise REAL"
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
        "SELECT temp, hum, light, pm25, pm10, aqi FROM sensor_data "
        "ORDER BY timestamp DESC LIMIT %1"
    ).arg(MAX_POINTS_24H);

    if (!query.exec(sql)) {
        Logger::instance()->warning("DB", QString("Failed to load buffer: %1").arg(query.lastError().text()));
        return false;
    }

    m_tempBuffer.clear();
    m_humBuffer.clear();
    m_lightBuffer.clear();
    m_pm25Buffer.clear();
    m_pm10Buffer.clear();
    m_aqiBuffer.clear();

    QList<double> tempList, humList, lightList, pm25List, pm10List, aqiList;
    while (query.next()) {
        tempList.prepend(query.value(0).toDouble());
        humList.prepend(query.value(1).toDouble());
        lightList.prepend(query.value(2).toDouble());
        pm25List.prepend(query.value(3).toDouble());
        pm10List.prepend(query.value(4).toDouble());
        aqiList.prepend(query.value(5).toDouble());
    }

    m_tempBuffer = tempList;
    m_humBuffer = humList;
    m_lightBuffer = lightList;
    m_pm25Buffer = pm25List;
    m_pm10Buffer = pm10List;
    m_aqiBuffer = aqiList;

    Logger::instance()->debug("DB", QString("Loaded %1 records from database").arg(m_tempBuffer.size()));
    return true;
}

bool Backstage::updateDatabase(double t, double h, double light, double pm25, double pm10, double aqi) {
    if (!m_db.isOpen()) {
        qWarning() << "[DB] Database not open, cannot update";
        return false;
    }

    QSqlQuery query(m_db);
    query.prepare(
        "INSERT INTO sensor_data (timestamp, temp, hum, light, pm25, pm10, aqi) "
        "VALUES (:timestamp, :temp, :hum, :light, :pm25, :pm10, :aqi)"
    );

    QString now = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss");
    query.bindValue(":timestamp", now);
    query.bindValue(":temp", t);
    query.bindValue(":hum", h);
    query.bindValue(":light", light);
    query.bindValue(":pm25", pm25);
    query.bindValue(":pm10", pm10);
    query.bindValue(":aqi", aqi);

    if (!query.exec()) {
        qCritical() << "[DB] Failed to insert data:" << query.lastError().text();
        return false;
    }
    return true;
}

void Backstage::processSnapshot() {
    auto updateBuf = [this](QList<double> &list, double val) {
        list.append(val);
        if (list.size() > MAX_POINTS_24H) {
            list.removeFirst();
        }
    };

    updateBuf(m_tempBuffer, m_currentTemp);
    updateBuf(m_humBuffer, m_currentHum);
    updateBuf(m_lightBuffer, m_currentLight);
    updateBuf(m_pm25Buffer, m_currentPM25);
    updateBuf(m_pm10Buffer, m_currentPM10);
    updateBuf(m_aqiBuffer, m_currentAQI);

    // 只有在非模拟模式下才写入数据库和上传到服务器
    if (!m_mockMode) {
        updateDatabase(m_currentTemp, m_currentHum, m_currentLight, m_currentPM25, m_currentPM10, m_currentAQI);
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
    data["gas"] = m_currentGas;
    data["air_quality"] = m_currentAQI;

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

double Backstage::getPM25() const {
    return m_currentPM25;
}

double Backstage::getPM10() const {
    return m_currentPM10;
}

double Backstage::getAQI() const {
    return m_currentAQI;
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

void Backstage::setPM25(double pm25) {
    m_currentPM25 = pm25;
}

void Backstage::setPM10(double pm10) {
    m_currentPM10 = pm10;
}

void Backstage::setAQI(double aqi) {
    m_currentAQI = aqi;
}

double Backstage::getGas() const {
    return m_currentGas;
}

void Backstage::setGas(double gas) {
    m_currentGas = gas;
}

QList<double> Backstage::getTempBuffer() const {
    return m_tempBuffer;
}

QList<double> Backstage::getHumBuffer() const {
    return m_humBuffer;
}

QList<double> Backstage::getLightBuffer() const {
    return m_lightBuffer;
}

QList<double> Backstage::getPM25Buffer() const {
    return m_pm25Buffer;
}

QList<double> Backstage::getPM10Buffer() const {
    return m_pm10Buffer;
}

QList<double> Backstage::getAQIBuffer() const {
    return m_aqiBuffer;
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
    
    if (m_db.isOpen()) {
        QSqlQuery query(m_db);
        if (!query.exec("UPDATE sensor_data SET temp = NULL")) {
            Logger::instance()->warning("DB", QString("Failed to clear temp in database: %1").arg(query.lastError().text()));
        }
    }
}

void Backstage::clearHumBuffer() {
    m_humBuffer.clear();
    
    if (m_db.isOpen()) {
        QSqlQuery query(m_db);
        if (!query.exec("UPDATE sensor_data SET hum = NULL")) {
            Logger::instance()->warning("DB", QString("Failed to clear hum in database: %1").arg(query.lastError().text()));
        }
    }
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

void Backstage::clearPM25Buffer() {
    m_pm25Buffer.clear();
    
    if (m_db.isOpen()) {
        QSqlQuery query(m_db);
        if (!query.exec("UPDATE sensor_data SET pm25 = NULL")) {
            Logger::instance()->warning("DB", QString("Failed to clear pm25 in database: %1").arg(query.lastError().text()));
        }
    }
}

void Backstage::clearPM10Buffer() {
    m_pm10Buffer.clear();
    
    if (m_db.isOpen()) {
        QSqlQuery query(m_db);
        if (!query.exec("UPDATE sensor_data SET pm10 = NULL")) {
            Logger::instance()->warning("DB", QString("Failed to clear pm10 in database: %1").arg(query.lastError().text()));
        }
    }
}

void Backstage::clearAQIBuffer() {
    m_aqiBuffer.clear();
    
    if (m_db.isOpen()) {
        QSqlQuery query(m_db);
        if (!query.exec("UPDATE sensor_data SET aqi = NULL")) {
            Logger::instance()->warning("DB", QString("Failed to clear aqi in database: %1").arg(query.lastError().text()));
        }
    }
}

void Backstage::clearAllBuffers() {
    clearTempBuffer();
    clearHumBuffer();
    clearLightBuffer();
    clearPM25Buffer();
    clearPM10Buffer();
    clearAQIBuffer();
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

double Backstage::calculateAQI(double pm25) {
    if (pm25 <= 35) return pm25 * 50 / 35;
    if (pm25 <= 75) return 50 + (pm25 - 35) * 50 / 40;
    if (pm25 <= 115) return 100 + (pm25 - 75) * 50 / 40;
    if (pm25 <= 150) return 150 + (pm25 - 115) * 50 / 35;
    if (pm25 <= 250) return 200 + (pm25 - 150) * 100 / 100;
    return 300 + (pm25 - 250) * 200 / 250;
}

void Backstage::handleZP(const QVariantMap &data) {
    double pm25 = m_currentPM25;
    if (data.contains("pm25")) {
        pm25 = data["pm25"].toDouble();
        setPM25(pm25);
    }
    if (data.contains("pm10")) {
        setPM10(data["pm10"].toDouble());
    }
    
    double aqi = calculateAQI(pm25);
    setAQI(aqi);
    
    emit valueSig();
}

void Backstage::handleMQ135(const QVariantMap &data) {
    if (data.contains("gas")) {
        setGas(data["gas"].toDouble());
    }
    emit valueSig();
}
