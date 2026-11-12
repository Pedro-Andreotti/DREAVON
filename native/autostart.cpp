#include "autostart.h"

#include <QCoreApplication>
#include <QDir>
#include <QSettings>
#include <QStringList>

namespace {
const QString RunKey = QStringLiteral("HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Run");
const QString ValueName = QStringLiteral("DREAVON");

QString quoted(const QString &arg) {
    return arg.contains(QLatin1Char(' ')) || arg.contains(QLatin1Char('\t')) ? QLatin1Char('"') + arg + QLatin1Char('"') : arg;
}
}

Autostart::Autostart(QObject *parent) : QObject(parent) {}

// Só quando o app foi aberto do jeito local conhecido: qml.exe com windows/dreavon.qml (atalho do
// Menu Iniciar ou build-windows.ps1 -Run).
bool Autostart::supported() const {
#ifdef Q_OS_WIN
    for (const QString &arg : QCoreApplication::arguments())
        if (arg.endsWith(QStringLiteral("dreavon.qml"), Qt::CaseInsensitive)) return true;
#endif
    return false;
}

// O comando que abriu o app agora, com "-- --bandeja" no fim.
QString Autostart::command() const {
    QStringList args = QCoreApplication::arguments();
    args[0] = QDir::toNativeSeparators(QCoreApplication::applicationFilePath());
    const int sep = args.indexOf(QStringLiteral("--"));
    if (sep >= 0) args = args.mid(0, sep);
    args << QStringLiteral("--") << QStringLiteral("--bandeja");
    QStringList parts;
    for (const QString &a : args) parts << quoted(a);
    return parts.join(QLatin1Char(' '));
}

bool Autostart::enabled() const {
#ifdef Q_OS_WIN
    QSettings run(RunKey, QSettings::NativeFormat);
    return run.contains(ValueName);
#else
    return false;
#endif
}

void Autostart::setEnabled(bool on) {
#ifdef Q_OS_WIN
    if (!supported() || on == enabled()) return;
    QSettings run(RunKey, QSettings::NativeFormat);
    if (on) run.setValue(ValueName, command());
    else run.remove(ValueName);
    run.sync();
    emit changed();
#else
    Q_UNUSED(on);
#endif
}
