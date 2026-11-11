// Inicializador do DREAVON: abre package/contents/ui/main.qml numa janela comum (sem Plasma).
#include <QApplication>
#include <QDir>
#include <QFileInfo>
#include <QQmlApplicationEngine>
#include <QUrl>

namespace {
// Procura uma pasta do projeto ao lado do executável (instalação) e, se não houver, no código-fonte.
QString findDir(const QString &relative) {
    const QStringList roots = {QCoreApplication::applicationDirPath(), QStringLiteral(DREAVON_SOURCE_DIR)};
    for (const QString &root : roots) {
        const QString path = QDir(root).filePath(relative);
        if (QFileInfo::exists(path)) return QDir::cleanPath(path);
    }
    return {};
}
}

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    // O nome define as pastas de dados: no Windows, %APPDATA%\DREAVON (configurações).
    QCoreApplication::setApplicationName(QStringLiteral("DREAVON"));
    QCoreApplication::setOrganizationName(QString());
    // A janela fecha para a bandeja; o aplicativo só sai pelo menu "Sair".
    QApplication::setQuitOnLastWindowClosed(false);

    QQmlApplicationEngine engine;
#ifdef Q_OS_WIN
    // Substituto mínimo do Kirigami (o Linux usa o Kirigami do KDE).
    const QString shim = findDir(QStringLiteral("windows/qml"));
    if (!shim.isEmpty()) engine.addImportPath(shim);
#endif
    const QString mainQml = findDir(QStringLiteral("package/contents/ui/main.qml"));
    if (mainQml.isEmpty()) { qCritical("main.qml não encontrado."); return 1; }
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.load(QUrl::fromLocalFile(mainQml));
    return app.exec();
}
