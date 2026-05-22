#ifndef SCREENSHOTMANAGER_H
#define SCREENSHOTMANAGER_H

#include <QObject>
#include <QTimer>
#include <QScreen>
#include <QDir>

class ScreenshotManager : public QObject {
    Q_OBJECT
public:
    static ScreenshotManager* instance();
    ~ScreenshotManager() override;
    
    Q_INVOKABLE void startCapturing();
    Q_INVOKABLE void stopCapturing();
    Q_INVOKABLE void captureNow();
    
    void setCaptureInterval(int seconds);
    void setMaxImageCount(int count);
    void setSavePath(const QString& path);
    
signals:
    void screenshotCaptured(const QString& filePath);
    void uploadSuccess(const QString& filePath);
    void uploadFailed(const QString& filePath, const QString& error);
    
private slots:
    void onCaptureTimer();
    
private:
    explicit ScreenshotManager(QObject *parent = nullptr);
    
    bool captureScreenshot();
    QString generateFileName();
    bool saveScreenshot(const QPixmap& pixmap, const QString& filePath);
    void cleanupOldImages();
    void uploadScreenshot(const QString& filePath);
    
    QTimer* m_captureTimer;
    int m_captureInterval;
    int m_maxImageCount;
    QString m_savePath;
    QString m_lastFilePath;
};

#endif // SCREENSHOTMANAGER_H