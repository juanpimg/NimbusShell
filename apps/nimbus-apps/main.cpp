// nimbus-apps — ventana Apps estilo Tahoe (R-APPSVIEW). F6-T04.
// Ventana centrada ~1000x700, Cmd+1 vía DBus toggle, --demo abre directo.
#include "appmodel.h"

#include <QApplication>
#include <QCommandLineParser>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QIcon>
#include <QObject>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QScreen>
#include <QTimer>

class AppsController : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.nimbus.Apps")
public:
    explicit AppsController(QQuickWindow *w, QObject *parent = nullptr)
        : QObject(parent), m_win(w) {}
public slots:
    void toggle() { m_win && m_win->isVisible() ? hide() : show(); }
    void show() {
        if (!m_win) return;
        m_win->show();
        m_win->raise();
        m_win->requestActivate();
    }
    void hide() { if (m_win) m_win->hide(); }
private:
    QQuickWindow *m_win = nullptr;
};

int main(int argc, char **argv)
{
    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("nimbus-apps"));
    app.setOrganizationName(QStringLiteral("NimbusShell"));
    QIcon::setFallbackThemeName(QStringLiteral("breeze"));

    QCommandLineParser p;
    p.addOption({QStringLiteral("toggle"), QStringLiteral("Alterna mostrar/ocultar vía DBus y sale.")});
    p.addOption({QStringLiteral("demo"), QStringLiteral("Abre la ventana directamente.")});
    p.addOption({QStringLiteral("view"), QStringLiteral("Vista inicial (icons|list)."), QStringLiteral("vista")});
    p.addOption({QStringLiteral("category"), QStringLiteral("Categoría inicial."), QStringLiteral("cat")});
    p.addOption({QStringLiteral("shot"), QStringLiteral("Guarda captura PNG y sale (test nested)."), QStringLiteral("png")});
    p.process(app);

    if (p.isSet(QStringLiteral("toggle"))) {
        // Habla con la instancia viva; si no existe, la arranca.
        auto bus = QDBusConnection::sessionBus();
        if (bus.interface()->isServiceRegistered(QStringLiteral("org.nimbus.Apps"))) {
            bus.call(QDBusMessage::createMethodCall(
                QStringLiteral("org.nimbus.Apps"), QStringLiteral("/Apps"),
                QStringLiteral("org.nimbus.Apps"), QStringLiteral("toggle")),
                QDBus::NoBlock);
            return 0;
        }
        // Sin instancia: arranca en modo demo (se registra abajo).
        p.setSingleDashWordOptionMode(QCommandLineParser::ParseAsLongOptions);
    }

    QQmlApplicationEngine engine;
    AppModel model;
    engine.rootContext()->setContextProperty(QStringLiteral("appModel"), &model);
    engine.addImageProvider(QStringLiteral("nimbusicons"), new NimbusIconProvider);
    engine.addImportPath(QStringLiteral("qrc:/"));
    engine.loadFromModule(QStringLiteral("Nimbus.Apps"), QStringLiteral("AppsWindow"));
    if (engine.rootObjects().isEmpty()) return 1;
    auto *win = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (!win) return 1;
    win->setFlags(Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint | Qt::Dialog);
    if (const QScreen *s = app.primaryScreen()) {
        const QRect g = s->availableGeometry();
        win->setX(g.center().x() - win->width() / 2);
        win->setY(g.center().y() - win->height() / 2);
    }

    AppsController ctl(win);
    QDBusConnection::sessionBus().registerService(QStringLiteral("org.nimbus.Apps"));
    QDBusConnection::sessionBus().registerObject(QStringLiteral("/Apps"), &ctl,
        QDBusConnection::ExportAllSlots);

    // Cierre con Esc ya en QML; perder foco NO oculta (ventana normal Tahoe).
    if (!p.isSet(QStringLiteral("demo")) && !p.isSet(QStringLiteral("toggle")))
        win->hide(); // arranca oculta: la muestra el atajo Cmd+1
    else
        ctl.show();

    // En --demo sin sesión gráfica persistente, nada especial.
    if (p.value(QStringLiteral("view")) == QLatin1String("list")) model.setListMode(true);
    const QString initCat = p.value(QStringLiteral("category"));
    if (!initCat.isEmpty() && model.fixedCategories().contains(initCat))
        model.setCategory(initCat);
    QTimer::singleShot(0, [&] { win->requestActivate(); });
    const QString shot = p.value(QStringLiteral("shot"));
    if (!shot.isEmpty()) {
        // Test nested: captura propia tras pintar y sale (rc=1 si falla).
        QTimer::singleShot(2500, [&, shot] {
            const QImage img = win->grabWindow();
            if (img.isNull() || !img.save(shot)) exit(1);
            exit(0);
        });
    }
    return app.exec();
}

#include "main.moc"
