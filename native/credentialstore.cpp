#include "credentialstore.h"

#include <QSettings>

#ifdef Q_OS_WIN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <wincred.h>
#endif

namespace {
const QString Prefix = QStringLiteral("DREAVON/");
const QString Unsupported = QStringLiteral("não suportado nesta plataforma");

#ifdef Q_OS_WIN
// Só o código do erro do Windows: nunca o conteúdo do segredo.
QString windowsError(const char *action) {
    return QStringLiteral("%1 falhou (erro %2 do Windows)").arg(QLatin1String(action)).arg(GetLastError());
}
#endif
}

bool CredentialStore::supported() {
#ifdef Q_OS_WIN
    return true;
#else
    return false;
#endif
}

bool CredentialStore::validTarget(const QString &target) {
    return target.startsWith(Prefix) && target.size() > Prefix.size() && target.size() < 256;
}

void CredentialStore::setError(const QString &error) {
    if (error == m_lastError) return;
    m_lastError = error;
    emit lastErrorChanged();
}

bool CredentialStore::set(const QString &target, const QString &secret) {
    if (!validTarget(target)) { setError(QStringLiteral("destino inválido")); return false; }
#ifdef Q_OS_WIN
    QByteArray blob = secret.trimmed().toUtf8();
    if (blob.isEmpty()) { setError(QStringLiteral("chave vazia")); return false; }
    if (blob.size() > CRED_MAX_CREDENTIAL_BLOB_SIZE) { setError(QStringLiteral("chave grande demais")); return false; }
    const std::wstring name = target.toStdWString();
    const std::wstring user = QStringLiteral("DREAVON").toStdWString();
    CREDENTIALW cred = {};
    cred.Type = CRED_TYPE_GENERIC;
    cred.TargetName = const_cast<LPWSTR>(name.c_str());
    cred.UserName = const_cast<LPWSTR>(user.c_str());
    cred.CredentialBlobSize = DWORD(blob.size());
    cred.CredentialBlob = reinterpret_cast<LPBYTE>(blob.data());
    cred.Persist = CRED_PERSIST_LOCAL_MACHINE;   // só nesta máquina, sem sincronizar com o perfil móvel
    const bool ok = CredWriteW(&cred, 0);
    SecureZeroMemory(blob.data(), size_t(blob.size()));
    if (!ok) { setError(windowsError("Salvar a chave")); return false; }
    setError({}); ++m_revision; emit changed();
    return true;
#else
    Q_UNUSED(secret);
    setError(Unsupported);
    return false;
#endif
}

QString CredentialStore::read(const QString &target, QString *error) {
    if (!validTarget(target)) { if (error) *error = QStringLiteral("destino inválido"); return {}; }
#ifdef Q_OS_WIN
    PCREDENTIALW cred = nullptr;
    if (!CredReadW(reinterpret_cast<LPCWSTR>(target.utf16()), CRED_TYPE_GENERIC, 0, &cred)) {
        if (error) *error = GetLastError() == ERROR_NOT_FOUND ? QString() : windowsError("Ler a chave");
        return {};
    }
    const QString secret = QString::fromUtf8(reinterpret_cast<const char *>(cred->CredentialBlob), int(cred->CredentialBlobSize));
    SecureZeroMemory(cred->CredentialBlob, cred->CredentialBlobSize);
    CredFree(cred);
    if (error) error->clear();
    return secret;
#else
    if (error) *error = Unsupported;
    return {};
#endif
}

QString CredentialStore::get(const QString &target) {
    QString error;
    const QString secret = read(target, &error);
    setError(error);
    return secret;
}

bool CredentialStore::exists(const QString &target) {
    if (!validTarget(target)) { setError(QStringLiteral("destino inválido")); return false; }
#ifdef Q_OS_WIN
    PCREDENTIALW cred = nullptr;
    if (!CredReadW(reinterpret_cast<LPCWSTR>(target.utf16()), CRED_TYPE_GENERIC, 0, &cred)) {
        setError(GetLastError() == ERROR_NOT_FOUND ? QString() : windowsError("Ler a chave"));
        return false;
    }
    const bool found = cred->CredentialBlobSize > 0;
    SecureZeroMemory(cred->CredentialBlob, cred->CredentialBlobSize);
    CredFree(cred);
    setError({});
    return found;
#else
    setError(Unsupported);
    return false;
#endif
}

bool CredentialStore::remove(const QString &target) {
    if (!validTarget(target)) { setError(QStringLiteral("destino inválido")); return false; }
#ifdef Q_OS_WIN
    if (!CredDeleteW(reinterpret_cast<LPCWSTR>(target.utf16()), CRED_TYPE_GENERIC, 0) && GetLastError() != ERROR_NOT_FOUND) {
        setError(windowsError("Remover a chave"));
        return false;
    }
    setError({}); ++m_revision; emit changed();
    return true;
#else
    setError(Unsupported);
    return false;
#endif
}

bool CredentialStore::migrateFromSettings(const QUrl &iniFile, const QString &key, const QString &target) {
    if (!supported()) { setError(Unsupported); return false; }
    const QString path = iniFile.isLocalFile() ? iniFile.toLocalFile() : iniFile.toString();
    QSettings ini(path, QSettings::IniFormat);
    if (!ini.contains(key)) return false;
    const QString old = ini.value(key).toString();
    if (!old.trimmed().isEmpty() && !set(target, old)) return false;   // não apaga se não conseguiu guardar
    ini.remove(key);
    ini.sync();
    return !old.trimmed().isEmpty();
}
