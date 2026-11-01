// probe-model (F3-T07-fix): instancia el StatusNotifierModel REAL contra
// el mini-watcher + fakes. Éxito (exit 0): el modelo ve 2 items y tras
// el quit de A queda en 1 sin crash (unregister).
#include <QCoreApplication>
#include <QTimer>
#include <cstdio>
#include "statusnotifiermodel.h"

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    StatusNotifierModel m;
    QObject::connect(&m, &StatusNotifierModel::countChanged, [&m]() {
        fprintf(stderr, "probe: count=%d\n", m.rowCount());
        for (int r = 0; r < m.rowCount(); ++r) {
            fprintf(stderr, "probe: row %d title=%s\n", r,
                    m.data(m.index(r, 0), StatusNotifierModel::TitleRole)
                        .toString()
                        .toUtf8()
                        .constData());
        }
        fflush(stderr);
    });
    fprintf(stderr, "probe: initial count=%d\n", m.rowCount());
    fflush(stderr);
    QTimer::singleShot(12000, [&m]() {
        const int c = m.rowCount();
        fprintf(stderr, "probe: final count=%d %s\n", c,
                c == 1 ? "UNREGISTER_OK" : "UNREGISTER_FAIL");
        fflush(stderr);
        QCoreApplication::exit(c == 1 ? 0 : 1);
    });
    return app.exec();
}
