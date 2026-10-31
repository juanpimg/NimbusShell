// nimbus-spotlight — overlay centrado con backend KRunner (F6-T01 Plan B).
// Flags: --demo (matches falsos), --query <t> (búsqueda inicial),
//   --shot <png> (captura propia tras pintar, para test nested).
#include <QDebug>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickImageProvider>
#include <QQuickWindow>
#include <QScreen>
#include <QTimer>
#include <QWindow>
#include <QtDBus/QDBusConnection>
#include <cstdio>
#include <unistd.h>

#include <LayerShellQt/Shell>
#include <LayerShellQt/Window>

#include "krunnerbackend.h"
#include "nimbusindex.h"

class IconProvider : public QQuickImageProvider {
public:
    IconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}
    QPixmap requestPixmap(const QString &id, QSize *size,
                          const QSize &requestedSize) override
    {
        const int s = requestedSize.isValid() ? requestedSize.width() : 32;
        QPixmap pm = QIcon::fromTheme(id).pixmap(s, s);
        if (size)
            *size = pm.size();
        return pm;
    }
};

class Toggle : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.nimbus.Spotlight")
public:
    explicit Toggle(QWindow *w, QObject *parent = nullptr)
        : QObject(parent), m_win(w) {}
public Q_SLOTS:
    void toggle()
    {
        m_win->setVisible(!m_win->isVisible());
        if (m_win->isVisible())
            m_win->requestActivate();
    }
private:
    QWindow *m_win = nullptr;
};

static void centerOnScreen(QWindow *win, int w, int h)
{
    QScreen *sc = QGuiApplication::primaryScreen();
    const QRect g = sc ? sc->geometry() : QRect(0, 0, 1280, 800);
    // Tercio superior, centrado (contrato §3: overlay centrado arriba).
    const int x = g.x() + (g.width() - w) / 2;
    const int y = g.y() + int(g.height() * 0.22);
    win->setGeometry(QRect(x, y, w, h));
}

int main(int argc, char *argv[])
{
    fprintf(stderr, "SPOT-MAIN-ENTER pid=%d\n", (int)getpid());
#if defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif
    LayerShellQt::Shell::useLayerShell();
#if defined(__GNUC__)
#pragma GCC diagnostic pop
#endif

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("nimbus-spotlight"));
    app.setOrganizationName(QStringLiteral("nimbus"));

    // Este Qt no emite qInfo/qWarning por defecto (verificado con binario
    // mínimo; nimbus-bar hace lo mismo con --log-query): handler propio.
    qInstallMessageHandler([](QtMsgType t, const QMessageLogContext &,
                              const QString &m) {
        fprintf(stderr, "nimbus-spotlight[%d]: %s\n", static_cast<int>(t),
                m.toUtf8().constData());
    });

    bool demo = false;
    QString initialQuery, shotPath;
    for (int i = 1; i < argc; ++i) {
        const QString a = QString::fromLocal8Bit(argv[i]);
        if (a == QStringLiteral("--demo"))
            demo = true;
        else if (a == QStringLiteral("--query") && i + 1 < argc)
            initialQuery = QString::fromLocal8Bit(argv[++i]);
        else if (a == QStringLiteral("--shot") && i + 1 < argc)
            shotPath = QString::fromLocal8Bit(argv[++i]);
    }

    KRunnerBackend backend(demo);
    NimbusIndex nimbus; // fast-path local F6-T02 (KRunner = fallback)
    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("nimbusicon"), new IconProvider);
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    engine.rootContext()->setContextProperty(QStringLiteral("nimbus"), &nimbus);
    engine.rootContext()->setContextProperty(QStringLiteral("initialQuery"), initialQuery);
    QObject::connect(&engine, &QQmlApplicationEngine::warnings,
                     [](const QList<QQmlError> &w) {
                         for (const auto &e : w)
                             qWarning().noquote() << e.toString();
                     });
    engine.load(QStringLiteral("qrc:/qml/Spotlight.qml"));
    if (engine.rootObjects().isEmpty()) {
        fprintf(stderr, "nimbus-spotlight: FALLO al cargar qrc:/qml/Spotlight.qml\n");
        qWarning("nimbus-spotlight: fallo al cargar qrc:/qml/Spotlight.qml");
        return 1;
    }
    auto *win = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (!win) {
        qWarning("nimbus-spotlight: root no es Window");
        return 1;
    }

    // Overlay centrado: capa Overlay sobre todo, sin zona exclusiva
    // (no desplaza ventanas), teclado exclusivo SOLO cuando visible.
    const int W = 680, H = 460;
    centerOnScreen(win, W, H);
    if (auto *ls = LayerShellQt::Window::get(win)) {
        ls->setLayer(LayerShellQt::Window::LayerOverlay);
        ls->setExclusiveZone(-1);
        ls->setKeyboardInteractivity(
            LayerShellQt::Window::KeyboardInteractivityExclusive);
        ls->setScope(QStringLiteral("nimbus-spotlight"));
    }
    QObject::connect(win, &QWindow::visibleChanged, win, [win](bool v) {
        if (auto *ls = LayerShellQt::Window::get(win)) {
            // Oculto: cede teclado (no robar cuando está oculto, §3).
            ls->setKeyboardInteractivity(v
                ? LayerShellQt::Window::KeyboardInteractivityExclusive
                : LayerShellQt::Window::KeyboardInteractivityNone);
        }
    });

    Toggle toggler(win);
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.registerService(QStringLiteral("org.nimbus.Spotlight")))
        qWarning("nimbus-spotlight: sin servicio DBus (otra instancia?)");
    else
        bus.registerObject(QStringLiteral("/Spotlight"), &toggler,
                           QDBusConnection::ExportAllSlots);

    qInfo().noquote() << QStringLiteral("nimbus-spotlight: demo=%1 query='%2'")
                             .arg(demo).arg(initialQuery);

    if (!shotPath.isEmpty()) {
        // Test nested: espera a resultados y vuelca píxeles a PNG.
        QTimer::singleShot(6000, win, [win, shotPath]() {
            if (auto *img = new QImage(win->grabWindow()); !img->isNull())
                img->save(shotPath);
            else
                qWarning("nimbus-spotlight: grabWindow vacío");
        });
    }
    return app.exec();
}

#include "main.moc"
