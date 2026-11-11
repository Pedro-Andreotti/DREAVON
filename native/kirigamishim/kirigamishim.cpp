// Plugin do substituto mínimo do Kirigami usado só no Windows (ver windows/qml/org/kde/kirigami).
// Fornece o tipo anexado Kirigami.FormData e um auxiliar para o FormLayout ler esses dados.
#include <QObject>
#include <QQmlEngine>
#include <QQmlExtensionPlugin>
#include <QtQml>

class FormDataAttached : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString label READ label WRITE setLabel NOTIFY labelChanged)
    Q_PROPERTY(bool isSection READ isSection WRITE setIsSection NOTIFY isSectionChanged)
    Q_PROPERTY(QObject *buddyFor READ buddyFor WRITE setBuddyFor NOTIFY buddyForChanged)
public:
    explicit FormDataAttached(QObject *parent) : QObject(parent) {}
    QString label() const { return m_label; }
    void setLabel(const QString &v) { if (v != m_label) { m_label = v; emit labelChanged(); } }
    bool isSection() const { return m_isSection; }
    void setIsSection(bool v) { if (v != m_isSection) { m_isSection = v; emit isSectionChanged(); } }
    QObject *buddyFor() const { return m_buddyFor; }
    void setBuddyFor(QObject *v) { if (v != m_buddyFor) { m_buddyFor = v; emit buddyForChanged(); } }
signals:
    void labelChanged();
    void isSectionChanged();
    void buddyForChanged();
private:
    QString m_label;
    bool m_isSection = false;
    QObject *m_buddyFor = nullptr;
};

class FormData : public QObject {
    Q_OBJECT
    QML_ATTACHED(FormDataAttached)
public:
    static FormDataAttached *qmlAttachedProperties(QObject *object) { return new FormDataAttached(object); }
};

class FormLayoutHelper : public QObject {
    Q_OBJECT
public:
    using QObject::QObject;
    // Devolve o FormData já anexado ao objeto (ou null, sem criar um novo).
    Q_INVOKABLE QObject *formData(QObject *object) const {
        return object ? qmlAttachedPropertiesObject<FormData>(object, false) : nullptr;
    }
};

class KirigamiShimPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char *uri) override {
        qmlRegisterUncreatableType<FormData>(uri, 2, 0, "FormData", QStringLiteral("FormData só existe como propriedade anexada."));
        qmlRegisterSingletonType<FormLayoutHelper>(uri, 2, 0, "FormLayoutHelper",
            [](QQmlEngine *, QJSEngine *) -> QObject * { return new FormLayoutHelper; });
    }
};

#include "kirigamishim.moc"
