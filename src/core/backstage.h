#ifndef BACKSTAGE_H
#define BACKSTAGE_H

#include <QObject>
#include <QDebug>
#include <QVariantMap>
#include <QDateTime>
#include <QTimer>
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QList>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QJsonObject>

class NetworkManager;

class Backstage : public QObject {
    Q_OBJECT

public:
    static Backstage* instance();

    double getTemp() const;
    void setTemp(double temp);
    double getHum() const;
    void setHum(double hum);
    double getLight() const;
    void setLight(double light);
    double getPM25() const;
    void setPM25(double pm25);
    double getPM10() const;
    void setPM10(double pm10);
    double getAQI() const;
    void setAQI(double aqi);
    double getGas() const;
    void setGas(double gas);

    // 为 Core 提供数据访问
    QList<double> getTempBuffer() const;
    QList<double> getHumBuffer() const;
    QList<double> getLightBuffer() const;
    QList<double> getPM25Buffer() const;
    QList<double> getPM10Buffer() const;
    QList<double> getAQIBuffer() const;

    // 清空传感器buffer
    void clearTempBuffer();
    void clearHumBuffer();
    void clearLightBuffer();
    void clearPM25Buffer();
    void clearPM10Buffer();
    void clearAQIBuffer();
    void clearAllBuffers();

    // 返回当前每个历史数据点时间间隔
    int getMsPerPoint() const;

    // 设置是否在模拟模式
    void setMockMode(bool mockMode);
    bool isMockMode() const;

    // 数据库操作
    bool isDatabaseOpen() const;
    bool purgeOldData(int daysToKeep = 7);

public slots:
    void handleDHT11(const QVariantMap &data);
    void handleLight(const QVariantMap &data);
    void handleZP(const QVariantMap &data);
    void handleMQ135(const QVariantMap &data);
    void processSnapshot(); // 定时采样处理

signals:
    void valueSig();   // 实时数据更新
    void bufferSig();  // 缓冲区/采样点更新
    void errorOccurred(const QString &error);

private:
    explicit Backstage(QObject *parent = nullptr);
    ~Backstage();
    Backstage& operator=(const Backstage&) = delete;

    bool initStorage();
    bool initDatabase();
    bool updateDatabase(double t, double h, double light, double pm25, double pm10, double aqi);
    bool loadBufferFromDatabase();
    void uploadToServer();
    double calculateAQI(double pm25);

    QSqlDatabase m_db;
    QString m_dbPath;

    QList<double> m_tempBuffer;
    QList<double> m_humBuffer;
    QList<double> m_lightBuffer;
    QList<double> m_pm25Buffer;
    QList<double> m_pm10Buffer;
    QList<double> m_aqiBuffer;

    double m_currentTemp;
    double m_currentHum;
    double m_currentLight;
    double m_currentPM25;
    double m_currentPM10;
    double m_currentAQI;
    double m_currentGas;

    QTimer *m_sampleTimer;
    const int MAX_POINTS_24H;
    const int m_msPerPoint;

    bool m_mockMode;
    NetworkManager *m_networkManager;
};

#endif // BACKSTAGE_H
