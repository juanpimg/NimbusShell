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
    explicit Toggle(QQuickWindow *w, NimbusIndex *idx, QObject *parent = nullptr)
        : QObject(parent), m_win(w), m_index(idx) {}
public Q_SLOTS:
    void toggle()
    {
        m_win->setVisible(!m_win->isVisible());
        if (m_win->isVisible()) {
            m_win->requestActivate();
            focusSearch();
        }
    }
    // F6-T09: apertura directa en una pestaña (Cmd+2..4 vía KWin).
    // Sin doble instancia: reutiliza la ventana única + setTab QML.
    void showTab(const QString &tab)
    {
        if (!validTab(tab)) {
            qWarning().noquote() << QStringLiteral("showTab: pestaña inválida '%1'").arg(tab);
            return;
        }
        QMetaObject::invokeMethod(m_win, "setTab", Q_ARG(QVariant, QVariant(tab)));
        qInfo().noquote() << QStringLiteral("spotlight-tab=%1").arg(tab);
        m_win->setVisible(true);
        m_win->requestActivate();
        focusSearch();
    }
    void toggleTab(const QString &tab)
    {
        if (!validTab(tab)) {
            qWarning().noquote() << QStringLiteral("toggleTab: pestaña inválida '%1'").arg(tab);
            return;
        }
        const QString cur = m_win->property("tab").toString();
        if (m_win->isVisible() && cur == tab) {
            m_win->setVisible(false);
            return;
        }
        showTab(tab);
    }
    // F6-T08: gancho de benchmark (solo reexpone searchLocal síncrono;
    // permite cronometrar query local en caliente vía qdbus).
    void query(const QString &term)
    {
        if (m_index)
            m_index->searchLocal(term, QString());
    }
private:
    static bool validTab(const QString &t)
    {
        return t == QLatin1String("apps") || t == QLatin1String("files")
            || t == QLatin1String("actions") || t == QLatin1String("clipboard");
    }
    void focusSearch()
    {
        QMetaObject::invokeMethod(m_win, "focusSearch");
    }
    QQuickWindow *m_win = nullptr;
    NimbusIndex *m_index = nullptr;
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

    bool demo = false, daemon = false;
    QString initialQuery, shotPath;
    QString initialTab = QStringLiteral("apps");
    QString initialClipView = QStringLiteral("history");
    for (int i = 1; i < argc; ++i) {
        const QString a = QString::fromLocal8Bit(argv[i]);
        if (a == QStringLiteral("--demo"))
            demo = true;
        else if (a == QStringLiteral("--daemon"))
            daemon = true;
        else if (a == QStringLiteral("--query") && i + 1 < argc)
            initialQuery = QString::fromLocal8Bit(argv[++i]);
        else if (a == QStringLiteral("--shot") && i + 1 < argc)
            shotPath = QString::fromLocal8Bit(argv[++i]);
        else if (a == QStringLiteral("--tab") && i + 1 < argc) {
            const QString t = QString::fromLocal8Bit(argv[++i]);
            if (t == QLatin1String("apps") || t == QLatin1String("files")
                || t == QLatin1String("actions") || t == QLatin1String("clipboard"))
                initialTab = t;
        } else if (a == QStringLiteral("--clipview") && i + 1 < argc) {
            const QString v = QString::fromLocal8Bit(argv[++i]);
            if (v == QLatin1String("history") || v == QLatin1String("emoji"))
                initialClipView = v;
        }
    }

    KRunnerBackend backend(demo);
    NimbusIndex nimbus; // fast-path local F6-T02 (KRunner = fallback)
    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("nimbusicon"), new IconProvider);
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    engine.rootContext()->setContextProperty(QStringLiteral("nimbus"), &nimbus);
    engine.rootContext()->setContextProperty(QStringLiteral("initialQuery"), initialQuery);
    engine.rootContext()->setContextProperty(QStringLiteral("initialTab"), initialTab);
    engine.rootContext()->setContextProperty(QStringLiteral("initialClipView"), initialClipView);
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

    Toggle toggler(win, &nimbus);
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.registerService(QStringLiteral("org.nimbus.Spotlight")))
        qWarning("nimbus-spotlight: sin servicio DBus (otra instancia?)");
    else
        bus.registerObject(QStringLiteral("/Spotlight"), &toggler,
                           QDBusConnection::ExportAllSlots);

    // Arranque: visible solo en demo/consulta/captura; en --daemon (DBus
    // activation) queda oculta hasta el toggle del atajo.
    const bool startVisible = demo || !initialQuery.isEmpty() || !shotPath.isEmpty();
    if (startVisible) {
        win->setVisible(true);
        win->requestActivate();
    } else {
        win->setVisible(false);
    }
    qInfo().noquote() << QStringLiteral("nimbus-spotlight: demo=%1 daemon=%2 query='%3'")
                             .arg(demo).arg(daemon).arg(initialQuery);

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
