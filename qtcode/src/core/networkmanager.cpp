#include "networkmanager.h"
#include "logger.h"
#include <QUrl>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <QDir>

NetworkManager* NetworkManager::instance() {
    static NetworkManager instance;
    return &instance;
}

NetworkManager::NetworkManager(QObject *parent) : QObject(parent),
    m_networkManager(new QNetworkAccessManager(this)),
    m_isConnected(false),
    m_checkTimer(new QTimer(this))
{
    loadConfig();
    
    m_checkTimer->setInterval(30000);
    m_checkTimer->setSingleShot(false);
    connect(m_checkTimer, &QTimer::timeout, this, &NetworkManager::checkConnection);
    m_checkTimer->start();
    
    checkConnection();
}

void NetworkManager::loadConfig() {
    QString appDir = QDir::currentPath();
    QString configPath = appDir + "/ip_config.conf";
    
    QFile configFile(configPath);
    if (configFile.exists()) {
        if (configFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream in(&configFile);
            while (!in.atEnd()) {
                QString line = in.readLine().trimmed();
                if (line.startsWith("#") || line.isEmpty()) {
                    continue;
                }
                QStringList parts = line.split("=");
                if (parts.size() == 2) {
                    QString key = parts[0].trimmed();
                    QString value = parts[1].trimmed();
                    if (key == "WEB_SERVER_URL") {
                        m_serverUrl = value.remove("\"");
                        Logger::instance()->info("NETWORK", QString("Loaded server URL from config: %1").arg(m_serverUrl));
                        break;
                    }
                }
            }
            configFile.close();
        }
    }
    
    if (m_serverUrl.isEmpty()) {
        m_serverUrl = "http://10.27.102.53:5000/api/data";
        Logger::instance()->warning("NETWORK", "Config file not found or WEB_SERVER_URL not set, using default: " + m_serverUrl);
    }
}

NetworkManager::~NetworkManager() {
    if (m_checkTimer->isActive()) {
        m_checkTimer->stop();
    }
    delete m_networkManager;
    delete m_checkTimer;
}

bool NetworkManager::isConnected() const {
    return m_isConnected;
}

void NetworkManager::checkConnection() {
    QUrl url(m_serverUrl);
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, &NetworkManager::onNetworkReply);
}

void NetworkManager::onNetworkReply() {
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) return;
    
    bool connected = (reply->error() == QNetworkReply::NoError);
    
    if (connected != m_isConnected) {
        m_isConnected = connected;
        Logger::instance()->info("NETWORK", QString("Connection status: %1").arg(connected ? "connected" : "disconnected"));
        emit connectionStatusChanged(connected);
    }
    
    reply->deleteLater();
}

void NetworkManager::uploadData(const QJsonObject& data) {
    if (!m_isConnected) {
        Logger::instance()->warning("NETWORK", "Cannot upload data: network not connected");
        emit uploadFailed("Network not connected");
        return;
    }

    QUrl url(m_serverUrl);
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    QJsonDocument doc(data);
    QByteArray jsonData = doc.toJson(QJsonDocument::Compact);

    QNetworkReply *reply = m_networkManager->post(request, jsonData);
    connect(reply, &QNetworkReply::finished, this, &NetworkManager::onUploadReply);
}

void NetworkManager::onUploadReply() {
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) return;
    
    if (reply->error() == QNetworkReply::NoError) {
        QByteArray response = reply->readAll();
        Logger::instance()->info("NETWORK", QString("Data uploaded successfully: %1").arg(QString::fromUtf8(response)));
        emit uploadSuccess(response);
    } else {
        QString errorMsg = QString("Upload failed: %1").arg(reply->errorString());
        Logger::instance()->error("NETWORK", errorMsg);
        emit uploadFailed(errorMsg);
    }

    reply->deleteLater();
}
