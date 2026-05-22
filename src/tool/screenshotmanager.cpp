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
    connect(m_captureTimer, &QTimer::timeout, this, &ScreenshotManager::onCaptureTimer);
    
    Logger::instance()->info("SCREENSHOT", QString("Screenshot manager initialized. Save path: %1").arg(m_savePath));
    
    QDir dir(m_savePath);
    if (!dir.exists()) {
        bool created = dir.mkpath(m_savePath);
        if (created) {
            Logger::instance()->info("SCREENSHOT", QString("Created screenshot directory: %1").arg(m_savePath));
        } else {
            Logger::instance()->error("SCREENSHOT", QString("Failed to create screenshot directory: %1").arg(m_savePath));
        }
    } else {
        Logger::instance()->info("SCREENSHOT", QString("Screenshot directory already exists: %1").arg(m_savePath));
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
    Logger::instance()->info("SCREENSHOT", QString("Capture interval set to %1 seconds").arg(m_captureInterval));
}

void ScreenshotManager::setMaxImageCount(int count) {
    m_maxImageCount = count;
    Logger::instance()->info("SCREENSHOT", QString("Max image count set to %1").arg(m_maxImageCount));
}

void ScreenshotManager::setSavePath(const QString& path) {
    m_savePath = path;
    QDir dir(m_savePath);
    if (!dir.exists()) {
        dir.mkpath(m_savePath);
    }
    Logger::instance()->info("SCREENSHOT", QString("Save path set to: %1").arg(m_savePath));
}

void ScreenshotManager::startCapturing() {
    if (!m_captureTimer->isActive()) {
        m_captureTimer->setInterval(m_captureInterval * 1000);
        m_captureTimer->start();
        Logger::instance()->info("SCREENSHOT", QString("Screenshot capturing started, interval: %1s").arg(m_captureInterval));
        onCaptureTimer();
    }
}

void ScreenshotManager::stopCapturing() {
    if (m_captureTimer->isActive()) {
        m_captureTimer->stop();
        Logger::instance()->info("SCREENSHOT", "Screenshot capturing stopped");
    }
}

void ScreenshotManager::captureNow() {
    Logger::instance()->info("SCREENSHOT", "Manual screenshot capture triggered");
    captureScreenshot();
}

void ScreenshotManager::onCaptureTimer() {
    captureScreenshot();
}

bool ScreenshotManager::captureScreenshot() {
    try {
        QScreen *screen = QGuiApplication::primaryScreen();
        if (!screen) {
            Logger::instance()->error("SCREENSHOT", "Failed to get primary screen");
            return false;
        }
        
        QPixmap pixmap;
        
        // 方法1：尝试捕获整个屏幕 (使用grabWindow(0))
        pixmap = screen->grabWindow(0);
        if (!pixmap.isNull()) {
            Logger::instance()->debug("SCREENSHOT", "Screenshot captured using grabWindow(0)");
        } else {
            // 方法2：尝试使用geometry捕获
            pixmap = screen->grabWindow(0, 0, 0, screen->geometry().width(), screen->geometry().height());
            if (!pixmap.isNull()) {
                Logger::instance()->debug("SCREENSHOT", "Screenshot captured using grabWindow with geometry");
            } else {
                // 方法3：尝试使用QPixmap::grabWindow
                pixmap = QPixmap::grabWindow(0);
                if (!pixmap.isNull()) {
                    Logger::instance()->debug("SCREENSHOT", "Screenshot captured using QPixmap::grabWindow");
                } else {
                    Logger::instance()->error("SCREENSHOT", "Failed to capture screenshot: all methods returned null pixmap");
                    return false;
                }
            }
        }
        
        QString filePath = m_savePath + "/" + generateFileName();
        if (saveScreenshot(pixmap, filePath)) {
            m_lastFilePath = filePath;
            Logger::instance()->info("SCREENSHOT", QString("Screenshot saved: %1").arg(filePath));
            emit screenshotCaptured(filePath);
            
            cleanupOldImages();
            uploadScreenshot(filePath);
            return true;
        } else {
            Logger::instance()->error("SCREENSHOT", QString("Failed to save screenshot: %1").arg(filePath));
            return false;
        }
    } catch (const std::exception& e) {
        Logger::instance()->error("SCREENSHOT", QString("Exception during screenshot capture: %1").arg(e.what()));
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
            Logger::instance()->info("SCREENSHOT", QString("Removed old screenshot: %1").arg(oldestFile));
            files.removeLast();
        } else {
            Logger::instance()->warning("SCREENSHOT", QString("Failed to remove old screenshot: %1").arg(oldestFile));
            break;
        }
    }
}

void ScreenshotManager::uploadScreenshot(const QString& filePath) {
    if (!NetworkManager::instance()->isConnected()) {
        Logger::instance()->warning("SCREENSHOT", "Cannot upload screenshot: network not connected");
        emit uploadFailed(filePath, "Network not connected");
        return;
    }
    
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        Logger::instance()->error("SCREENSHOT", QString("Failed to open screenshot file: %1").arg(filePath));
        emit uploadFailed(filePath, "Failed to open file");
        return;
    }
    
    QByteArray imageData = file.readAll();
    file.close();
    
    QUrl url("http://192.168.3.82:5000/api/screenshot");
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
            QByteArray response = reply->readAll();
            Logger::instance()->info("SCREENSHOT", QString("Screenshot uploaded successfully: %1").arg(QString::fromUtf8(response)));
            emit uploadSuccess(filePath);
        } else {
            QString errorMsg = QString("Upload failed: %1").arg(reply->errorString());
            Logger::instance()->error("SCREENSHOT", errorMsg);
            emit uploadFailed(filePath, errorMsg);
        }
        reply->deleteLater();
        manager->deleteLater();
    });
}