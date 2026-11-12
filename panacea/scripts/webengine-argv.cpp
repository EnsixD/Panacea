#include <QCoreApplication>
#include <QStringList>
#include <cstdlib>
#include <dlfcn.h>
__attribute__((constructor)) static void restore_environment() {
    const char *preload = std::getenv("PANACEA_ORIGINAL_LD_PRELOAD");
    if (preload && *preload) setenv("LD_PRELOAD", preload, 1); else unsetenv("LD_PRELOAD");
    unsetenv("PANACEA_ORIGINAL_LD_PRELOAD");
}
QStringList QCoreApplication::arguments() {
    using Fn = QStringList (*)();
    static auto real = reinterpret_cast<Fn>(dlsym(RTLD_NEXT, "_ZN16QCoreApplication9argumentsEv"));
    QStringList args = real ? real() : QStringList();
    if (args.isEmpty()) args.append(QStringLiteral("quickshell"));
    return args;
}
