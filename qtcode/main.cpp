#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include "src/core/coremanager.h"
#include "src/core/logger.h"
#include <QIcon>
#include <QQmlContext>
#include <QApplication>

int main(int argc, char *argv[])
{
//    qputenv("QT_IM_MODULE", QByteArray("qtvirtualkeyboard"));

    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);

    QApplication app(argc, argv);

    Logger::instance();

    Logger::instance()->info("MAIN", "EnviroTrend application started");

    QIcon icon("qrc:/res/logo/logo_transparentbg.png");
    app.setWindowIcon(icon);

    QQmlApplicationEngine engine;

    CoreManager *manager = new CoreManager(&app);
    engine.rootContext()->setContextProperty("core", manager);

    engine.load(QUrl(QStringLiteral("qrc:/main.qml")));
    if (engine.rootObjects().isEmpty()) {
        Logger::instance()->error("MAIN", "Failed to load main.qml");
        return -1;
    }

    int result = app.exec();
    
    Logger::instance()->info("MAIN", QString("EnviroTrend application exited with code: %1").arg(result));
    return result;
}
