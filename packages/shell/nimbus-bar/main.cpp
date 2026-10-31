// nimbus-bar — barra superior layer-shell 24pt (F3-T03, R-TOPBAR-LAYER).
// Contrato §3: menu bar 24pt, capa Top, anclada arriba, sin foco de teclado.
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlError>
#include <QWindow>
#include <QDebug>
#include <LayerShellQt/Shell>
#include <LayerShellQt/Window>

int main(int argc, char *argv[])
{
    // API LayerShellQt 6.8: obsoleta desde 6.6 (no necesaria desde Qt 6.5),
    // pero sigue disponible y es la llamada canónica del requisito F3-T03.
#if defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif
    LayerShellQt::Shell::useLayerShell();
#if defined(__GNUC__)
#pragma GCC diagnostic pop
#endif

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("nimbus-bar"));
    app.setOrganizationName(QStringLiteral("nimbus"));

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings,
                     [](const QList<QQmlError> &w) {
                         for (const auto &e : w)
                             qWarning().noquote() << e.toString();
                     });
    engine.load(QStringLiteral("qrc:/Bar.qml"));
    if (engine.rootObjects().isEmpty()) {
        qWarning("nimbus-bar: fallo al cargar qrc:/Bar.qml");
        return 1;
    }

    // Refuerzo en C++ de los mismos valores declarados en Bar.qml
    // (anclas/arriba, exclusiveZone 24, capa Top, sin teclado, scope).
    if (auto *win = qobject_cast<QWindow *>(engine.rootObjects().first())) {
        if (auto *ls = LayerShellQt::Window::get(win)) {
            ls->setAnchors({LayerShellQt::Window::AnchorTop,
                            LayerShellQt::Window::AnchorLeft,
                            LayerShellQt::Window::AnchorRight});
            ls->setExclusiveZone(24);
            ls->setLayer(LayerShellQt::Window::LayerTop);
            ls->setKeyboardInteractivity(
                LayerShellQt::Window::KeyboardInteractivityNone);
            ls->setScope(QStringLiteral("nimbus-bar"));
            ls->setActivateOnShow(false);
        }
    }

    return app.exec();
}
