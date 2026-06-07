#include "screenshotmanager.h"
#include "../core/logger.h"
#include "../core/networkmanager.h"
#include <QApplication>
#include <QCoreApplication>
#include <QScreen>
#include <QPixmap>
#include <QDateTime>
#include <QFile>
#include <QDir>
#include <QNetworkRequest>
#include <QHttpMultiPart>
#include <QNetworkAccessManager>
#include <QBuffer>
#include <QDesktopWidget>
#include <QTextStream>

ScreenshotManager* ScreenshotManager::instance() {
    static ScreenshotManager instance;
    return &instance;
}

ScreenshotManager::ScreenshotManager(QObject *parent) 
    : QObject(parent),
      m_captureTimer(new QTimer(this)),
      m_captureInterval(60),
      m_maxImageCount(20),
      m_savePath(QCoreApplication::applicationDirPath() + "/screenshot")
{
    loadConfig();
    
    connect(m_captureTimer, &QTimer::timeout, this, &ScreenshotManager::onCaptureTimer);
    
    QDir dir(m_savePath);
    if (!dir.exists()) {
        dir.mkpath(m_savePath);
    }
}

void ScreenshotManager::loadConfig() {
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
                    if (key == "SCREENSHOT_SERVER_URL") {
                        m_screenshotUrl = value.remove("\"");
                        break;
                    }
                }
            }
            configFile.close();
        }
    }
    
    if (m_screenshotUrl.isEmpty()) {
        m_screenshotUrl = "http://192.168.137.1:5000/api/screenshot";
    }
}

ScreenshotManager::~ScreenshotManager() {
    if (m_captureTimer->isActive()) {
        m_captureTimer->stop();
    }
    delete m_captureTimer;
}

void ScreenshotManager::setCaptureInterval(int seconds) {
    m_captureInterval = seconds;
    if (m_captureTimer->isActive()) {
        m_captureTimer->setInterval(m_captureInterval * 1000);
    }
}

void ScreenshotManager::setMaxImageCount(int count) {
    m_maxImageCount = count;
}

void ScreenshotManager::setSavePath(const QString& path) {
    m_savePath = path;
    QDir dir(m_savePath);
    if (!dir.exists()) {
        dir.mkpath(m_savePath);
    }
}

void ScreenshotManager::startCapturing() {
    if (!m_captureTimer->isActive()) {
        m_captureTimer->setInterval(m_captureInterval * 1000);
        m_captureTimer->start();
        onCaptureTimer();
    }
}

void ScreenshotManager::stopCapturing() {
    if (m_captureTimer->isActive()) {
        m_captureTimer->stop();
    }
}

void ScreenshotManager::captureNow() {
    captureScreenshot();
}

void ScreenshotManager::onCaptureTimer() {
    captureScreenshot();
}

bool ScreenshotManager::captureScreenshot() {
    try {
        QScreen *screen = QGuiApplication::primaryScreen();
        if (!screen) {
            return false;
        }
        
        QPixmap pixmap = screen->grabWindow(0);
        if (pixmap.isNull()) {
            pixmap = screen->grabWindow(0, 0, 0, screen->geometry().width(), screen->geometry().height());
        }
        if (pixmap.isNull()) {
            pixmap = QPixmap::grabWindow(0);
        }
        if (pixmap.isNull()) {
            return false;
        }
        
        QString filePath = m_savePath + "/" + generateFileName();
        if (saveScreenshot(pixmap, filePath)) {
            m_lastFilePath = filePath;
            emit screenshotCaptured(filePath);
            cleanupOldImages();
            uploadScreenshot(filePath);
            return true;
        }
        return false;
    } catch (const std::exception&) {
        return false;
    }
}

QString ScreenshotManager::generateFileName() {
    QString timestamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss");
    return QString("screenshot_%1.png").arg(timestamp);
}

bool ScreenshotManager::saveScreenshot(const QPixmap& pixmap, const QString& filePath) {
    return pixmap.save(filePath, "PNG");
}

void ScreenshotManager::cleanupOldImages() {
    QDir dir(m_savePath);
    QStringList filters;
    filters << "screenshot_*.png";
    dir.setNameFilters(filters);
    dir.setSorting(QDir::Time);
    
    QStringList files = dir.entryList(QDir::Files);
    
    while (files.size() > m_maxImageCount) {
        QString oldestFile = files.last();
        QString filePath = m_savePath + "/" + oldestFile;
        if (QFile::remove(filePath)) {
            files.removeLast();
        } else {
            break;
        }
    }
}

void ScreenshotManager::uploadScreenshot(const QString& filePath) {
    if (!NetworkManager::instance()->isConnected()) {
        emit uploadFailed(filePath, "Network not connected");
        return;
    }
    
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit uploadFailed(filePath, "Failed to open file");
        return;
    }
    
    QByteArray imageData = file.readAll();
    file.close();
    
    QUrl url(m_screenshotUrl);
    QNetworkRequest request(url);
    
    QHttpMultiPart *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);
    
    QHttpPart imagePart;
    imagePart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant("image/png"));
    imagePart.setHeader(QNetworkRequest::ContentDispositionHeader, 
                       QVariant("form-data; name=\"screenshot\"; filename=\"" + QFileInfo(filePath).fileName() + "\""));
    imagePart.setBody(imageData);
    
    multiPart->append(imagePart);
    
    QNetworkAccessManager* manager = new QNetworkAccessManager(this);
    QNetworkReply *reply = manager->post(request, multiPart);
    multiPart->setParent(reply);
    
    connect(reply, &QNetworkReply::finished, this, [=]() {
        if (reply->error() == QNetworkReply::NoError) {
            emit uploadSuccess(filePath);
        } else {
            emit uploadFailed(filePath, reply->errorString());
        }
        reply->deleteLater();
        manager->deleteLater();
    });
}