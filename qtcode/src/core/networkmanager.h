#ifndef NETWORKMANAGER_H
#define NETWORKMANAGER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QTimer>
#include <QJsonObject>
#include <QString>

class NetworkManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY connectionStatusChanged)

public:
    static NetworkManager* instance();
    ~NetworkManager() override;

    bool isConnected() const;

public slots:
    void checkConnection();
    void uploadData(const QJsonObject& data);

signals:
    void connectionStatusChanged(bool connected);
    void uploadSuccess(const QByteArray& response);
    void uploadFailed(const QString& error);

private slots:
    void onNetworkReply();
    void onUploadReply();

private:
    explicit NetworkManager(QObject *parent = nullptr);
    void loadConfig();
    QNetworkAccessManager *m_networkManager;
    bool m_isConnected;
    QTimer *m_checkTimer;
    QString m_serverUrl;
};

#endif // NETWORKMANAGER_H
