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
    double getZP01() const;
    void setZP01(double zp01);
    double getMQ135() const;
    void setMQ135(double mq135);

    // 为 Core 提供数据访问
    QList<double> getTempBuffer() const;
    QList<double> getHumBuffer() const;
    QList<double> getLightBuffer() const;
    QList<double> getZP01Buffer() const;
    QList<double> getMQ135Buffer() const;

    // 清空传感器buffer
    void clearTempBuffer();
    void clearHumBuffer();
    void clearLightBuffer();
    void clearZP01Buffer();
    void clearMQ135Buffer();
    void clearAllBuffers();

    // 返回当前每个历史数据点时间间隔
    int getMsPerPoint() const;

    // 获取数据预处理步长（每隔n个点取一个）
    int getSampleStep() const;

    // 获取预处理后的数据（QML直接使用）
    QVariantList getSampledTempBuffer() const;
    QVariantList getSampledHumBuffer() const;
    QVariantList getSampledLightBuffer() const;
    QVariantList getSampledZp01Buffer() const;
    QVariantList getSampledMq135Buffer() const;

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
    bool updateDatabase(double t, double h, double light, double mq135, double zp01);
    bool loadBufferFromDatabase();
    void uploadToServer();

    QSqlDatabase m_db;
    QString m_dbPath;

    QList<double> m_tempBuffer;
    QList<double> m_humBuffer;
    QList<double> m_lightBuffer;
    QList<double> m_zp01Buffer;
    QList<double> m_mq135Buffer;

    double m_currentTemp;
    double m_currentHum;
    double m_currentLight;
    double m_currentZP01;
    double m_currentMQ135;

    QTimer *m_sampleTimer;
    const int MAX_POINTS_24H;
    const int m_msPerPoint;
    const int m_sampleStep;

    bool m_mockMode;
    NetworkManager *m_networkManager;
};

#endif // BACKSTAGE_H
