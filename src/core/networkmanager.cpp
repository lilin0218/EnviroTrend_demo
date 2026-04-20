#include "networkmanager.h"
#include "logger.h"
#include <QUrl>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QDebug>

NetworkManager* NetworkManager::instance() {
    static NetworkManager instance;
    return &instance;
}

NetworkManager::NetworkManager(QObject *parent) : QObject(parent),
    m_networkManager(new QNetworkAccessManager(this)),
    m_isConnected(false),
    m_checkTimer(new QTimer(this))
{
    m_checkTimer->setInterval(30000);
    m_checkTimer->setSingleShot(false);
    connect(m_checkTimer, &QTimer::timeout, this, &NetworkManager::checkConnection);
    m_checkTimer->start();
    
    checkConnection();
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
    
    bool connected = false;
    
    if (reply->error() == QNetworkReply::NoError) {
        connected = true;
        Logger::instance()->info("NETWORK", "Connection is available");
    } else {
        Logger::instance()->warning("NETWORK", QString("Connection error: %1").arg(reply->errorString()));
    }
    
    if (connected != m_isConnected) {
        m_isConnected = connected;
        Logger::instance()->info("NETWORK", QString("Connection status changed: %1").arg(connected ? "connected" : "disconnected"));
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

    Logger::instance()->debug("NETWORK", QString("Uploading data: %1").arg(QString::fromUtf8(jsonData)));

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
