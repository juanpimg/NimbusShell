#!/usr/bin/env python3
"""
record-nimbus-demo.py — Grabador de demostración integral de UI/UX de NimbusShell.
Ejecuta una sesión KWin virtual Wayland aislada (1440x900) con wallpaper Sequoia,
despliega NimbusBar con estética Liquid Glass, semáforos nativos macOS Tahoe (Aurorae),
Dock translúcido Liquid Glass, Control Center con cápsulas 140x64 y sliders pills,
Calendario 6x7, OSD, Spotlight, Apps, Mission Control, Welcome Wizard y KCM Settings,
y graba un video MP4 fluido vía ScreenShot2 directo a ffmpeg sin usar pantalla física ni root.
"""

import os
import sys
import time
import subprocess
import signal
import shutil
import tempfile
import threading
import dbus

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BIN_DIR = os.path.join(REPO_ROOT, "out", "bin")
VIDEO_DIR = os.path.join(REPO_ROOT, "out", "videos")
FRAMES_DIR = os.path.join(VIDEO_DIR, "frames")
WALLPAPER = os.path.join(REPO_ROOT, "packages", "themes", "nimbus-tahoe", "wallpapers", "sequoia-dark.jpg")
DOCK_QML = os.path.join(REPO_ROOT, "packages", "dock", "qml", "Dock.qml")

WIDTH = 1440
HEIGHT = 900
FPS = 25
OUTPUT_MP4 = os.path.join(VIDEO_DIR, "nimbus-tahoe-ui-ux-demo.mp4")
OUTPUT_GIF = os.path.join(VIDEO_DIR, "nimbus-tahoe-ui-ux-demo.gif")

os.makedirs(VIDEO_DIR, exist_ok=True)
os.makedirs(FRAMES_DIR, exist_ok=True)

class DemoRecorder:
    def __init__(self):
        self.tmp_dir = tempfile.mkdtemp(prefix="nimbus-rec-")
        self.runtime_dir = os.path.join(self.tmp_dir, "runtime")
        self.config_dir = os.path.join(self.tmp_dir, "config")
        self.data_dir = os.path.join(self.tmp_dir, "data")
        self.home_dir = os.path.join(self.tmp_dir, "home")
        for d in [self.runtime_dir, self.config_dir, self.data_dir, self.home_dir]:
            os.makedirs(d, mode=0o700, exist_ok=True)

        self.socket_name = "nimbus-demo-socket"
        self.dbus_pid = None
        self.dbus_addr = None
        self.kwin_proc = None
        self.ffmpeg_proc = None
        self.recording = False
        self.record_thread = None
        self.managed_procs = []

    def log(self, msg):
        print(f"[demo-recorder] {msg}", flush=True)

    def setup_env(self):
        self.log(f"Configurando entorno aislado en {self.tmp_dir}")
        home_config = os.path.join(self.home_dir, ".config")
        home_local_share = os.path.join(self.home_dir, ".local", "share")
        os.makedirs(home_config, exist_ok=True)
        os.makedirs(home_local_share, exist_ok=True)

        # Copiar configuraciones base de plasma
        plasma_src = os.path.join(REPO_ROOT, "dotfiles", ".config", "plasma")
        if os.path.isdir(plasma_src):
            plasma_dest = os.path.join(home_config, "plasma")
            os.makedirs(plasma_dest, exist_ok=True)
            for f in os.listdir(plasma_src):
                s = os.path.join(plasma_src, f)
                if os.path.isfile(s) and not f.startswith("README"):
                    shutil.copy2(s, home_config)
                    shutil.copy2(s, plasma_dest)

        # Copiar temas Aurorae para semáforos Tahoe exactos
        aurorae_src = os.path.join(REPO_ROOT, "dotfiles", ".local", "share", "aurorae")
        aurorae_dest = os.path.join(home_local_share, "aurorae")
        aurorae_data_dest = os.path.join(self.data_dir, "aurorae")
        if os.path.isdir(aurorae_src):
            shutil.copytree(aurorae_src, aurorae_dest, dirs_exist_ok=True)
            shutil.copytree(aurorae_src, aurorae_data_dest, dirs_exist_ok=True)

        # Copiar esquemas de color
        colors_src = os.path.join(REPO_ROOT, "packages", "themes", "nimbus-tahoe", "colorschemes")
        colors_dest = os.path.join(home_local_share, "color-schemes")
        colors_data_dest = os.path.join(self.data_dir, "color-schemes")
        os.makedirs(colors_dest, exist_ok=True)
        os.makedirs(colors_data_dest, exist_ok=True)
        if os.path.isdir(colors_src):
            for c in os.listdir(colors_src):
                sc = os.path.join(colors_src, c)
                if os.path.isfile(sc):
                    shutil.copy2(sc, colors_dest)
                    shutil.copy2(sc, colors_data_dest)

        # Configurar variables de entorno
        self.env = os.environ.copy()
        self.env["HOME"] = self.home_dir
        self.env["XDG_RUNTIME_DIR"] = self.runtime_dir
        self.env["XDG_CONFIG_HOME"] = home_config
        self.env["XDG_DATA_HOME"] = home_local_share
        self.env["XDG_DATA_DIRS"] = f"{self.data_dir}:{home_local_share}:/usr/local/share:/usr/share"
        self.env["QT_QPA_PLATFORM"] = "wayland"
        self.env["WAYLAND_DISPLAY"] = self.socket_name
        self.env["XDG_SESSION_TYPE"] = "wayland"
        self.env["XDG_CURRENT_DESKTOP"] = "KDE"
        self.env["PATH"] = f"{BIN_DIR}:{self.env.get('PATH', '')}"

        # Integrar plugin Liquid Glass KWin y KCM Nimbus
        glass_plugins = "/tmp/glass-prefix/lib/plugins"
        kcm_bin = os.path.join(REPO_ROOT, "out", "build", "kcm_nimbus", "bin")
        self.env["QT_PLUGIN_PATH"] = f"{kcm_bin}:{glass_plugins}:/usr/lib/qt6/plugins:{self.env.get('QT_PLUGIN_PATH', '')}"

    def start_dbus(self):
        self.log("Iniciando D-Bus privado...")
        res = subprocess.check_output(
            ["dbus-daemon", "--session", "--print-address", "--fork"],
            env=self.env, text=True
        ).strip()
        self.dbus_addr = res
        self.env["DBUS_SESSION_BUS_ADDRESS"] = self.dbus_addr
        self.log(f"D-Bus listo en {self.dbus_addr}")

    def start_kwin(self):
        self.log(f"Iniciando KWin Wayland virtual ({WIDTH}x{HEIGHT})...")
        kwin_cmd = [
            "kwin_wayland", "--virtual",
            "--width", str(WIDTH), "--height", str(HEIGHT),
            "--no-lockscreen",
            "--socket", self.socket_name,
            "--xwayland"
        ]
        self.kwin_proc = subprocess.Popen(kwin_cmd, env=self.env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.managed_procs.append(self.kwin_proc)

        # Esperar socket wayland
        sock_path = os.path.join(self.runtime_dir, self.socket_name)
        for _ in range(60):
            if os.path.exists(sock_path):
                break
            time.sleep(0.1)
        if not os.path.exists(sock_path):
            raise RuntimeError(f"Tiempo de espera agotado para el socket Wayland {sock_path}")
        self.log("KWin Wayland iniciado y socket disponible.")

        # Esperar a que KWin se registre en D-Bus
        self.log("Esperando a que org.kde.KWin se registre en D-Bus...")
        bus = dbus.bus.BusConnection(self.dbus_addr)
        dbus_obj = bus.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus")
        dbus_iface = dbus.Interface(dbus_obj, "org.freedesktop.DBus")
        for _ in range(60):
            names = dbus_iface.ListNames()
            if "org.kde.KWin" in names:
                break
            time.sleep(0.2)
        if "org.kde.KWin" not in dbus_iface.ListNames():
            raise RuntimeError("Tiempo de espera agotado para registro de org.kde.KWin en D-Bus")
        self.log("org.kde.KWin registrado en D-Bus.")
        time.sleep(1.0)

        # Cargar efecto nativo Liquid Glass (Snell refraction + Dual Kawase blur)
        try:
            effects_obj = bus.get_object("org.kde.KWin", "/Effects")
            effects_iface = dbus.Interface(effects_obj, "org.kde.kwin.Effects")
            if not effects_iface.isEffectLoaded("liquidglass"):
                loaded = effects_iface.loadEffect("liquidglass")
                self.log(f"Efecto KWin Liquid Glass cargado dinámicamente: {bool(loaded)}")
            else:
                self.log("Efecto KWin Liquid Glass ya está activo.")
        except Exception as e:
            self.log(f"Aviso al cargar efecto Liquid Glass: {e}")

    def set_wallpaper_and_dock(self):
        wp_bin = os.path.join(BIN_DIR, "nimbus-wallpaper")
        if os.path.isfile(wp_bin) and os.path.isfile(WALLPAPER):
            self.log(f"Iniciando fondo de pantalla Sequoia en LayerBackground: {WALLPAPER}")
            self.spawn([wp_bin, WALLPAPER])
            time.sleep(1.0)

        if os.path.isfile(wp_bin) and os.path.isfile(DOCK_QML):
            self.log(f"Iniciando Dock Tahoe Liquid Glass en LayerTop: {DOCK_QML}")
            self.spawn([wp_bin, "--qml", DOCK_QML])
            time.sleep(0.8)

    def start_recorder(self):
        self.log(f"Iniciando pipeline ffmpeg hacia {OUTPUT_MP4} ({WIDTH}x{HEIGHT} @ {FPS} fps)...")
        ffmpeg_cmd = [
            "ffmpeg", "-y",
            "-f", "rawvideo",
            "-pixel_format", "bgra",
            "-video_size", f"{WIDTH}x{HEIGHT}",
            "-framerate", str(FPS),
            "-i", "-",
            "-c:v", "libx264",
            "-preset", "fast",
            "-crf", "18",
            "-pix_fmt", "yuv420p",
            OUTPUT_MP4
        ]
        self.ffmpeg_proc = subprocess.Popen(ffmpeg_cmd, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.recording = True

        def capture_loop():
            try:
                bus = dbus.bus.BusConnection(self.dbus_addr)
                kwin = None
                iface = None
                for _ in range(30):
                    try:
                        kwin = bus.get_object("org.kde.KWin", "/org/kde/KWin/ScreenShot2")
                        iface = dbus.Interface(kwin, "org.kde.KWin.ScreenShot2")
                        break
                    except Exception:
                        time.sleep(0.2)
                if not iface:
                    self.log("ERROR: no se pudo obtener interfaz ScreenShot2")
                    return
            except Exception as e:
                self.log(f"ERROR en conexión de captura: {e}")
                return

            frame_interval = 1.0 / FPS
            stride_expected = WIDTH * 4
            total_bytes = stride_expected * HEIGHT

            while self.recording and self.ffmpeg_proc.poll() is None:
                t_start = time.time()
                r, w = os.pipe()
                try:
                    res = iface.CaptureWorkspace({}, dbus.types.UnixFd(w))
                    os.close(w)
                    h = int(res.get("height", HEIGHT))
                    stride = int(res.get("stride", stride_expected))
                    tot = stride * h
                    chunks = []
                    n = 0
                    while n < tot:
                        chunk = os.read(r, min(tot - n, 1048576))
                        if not chunk:
                            break
                        chunks.append(chunk)
                        n += len(chunk)
                    os.close(r)
                    raw_data = b"".join(chunks)
                    if len(raw_data) == tot:
                        self.ffmpeg_proc.stdin.write(raw_data)
                except Exception as e:
                    try: os.close(w)
                    except: pass
                    try: os.close(r)
                    except: pass

                elapsed = time.time() - t_start
                sleep_time = max(0, frame_interval - elapsed)
                time.sleep(sleep_time)

        self.record_thread = threading.Thread(target=capture_loop, daemon=True)
        self.record_thread.start()
        self.log("Captura en segundo plano activa.")

    def stop_recorder(self):
        self.log("Finalizando grabación...")
        self.recording = False
        if self.record_thread:
            self.record_thread.join(timeout=3)
        if self.ffmpeg_proc:
            try:
                self.ffmpeg_proc.stdin.close()
            except: pass
            self.ffmpeg_proc.wait(timeout=10)
        self.log(f"Video MP4 generado exitosamente: {OUTPUT_MP4} ({os.path.getsize(OUTPUT_MP4) / 1024 / 1024:.2f} MB)")

    def spawn(self, cmd_list):
        self.log(f"Lanzando: {' '.join(cmd_list)}")
        p = subprocess.Popen(cmd_list, env=self.env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.managed_procs.append(p)
        return p

    def stop_proc(self, p, name=None):
        if p and p.poll() is None:
            try:
                p.terminate()
                p.wait(timeout=2.0)
            except subprocess.TimeoutExpired:
                p.kill()
                p.wait()
            except Exception:
                pass
        if name:
            subprocess.run(["pkill", "-9", "-f", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(0.3)

    def run_scene_script(self, kwin_js):
        """Ejecuta un script en KWin via DBus para mover ventanas o simular interacciones."""
        try:
            bus = dbus.bus.BusConnection(self.dbus_addr)
            kwin_scripting = bus.get_object("org.kde.KWin", "/Scripting")
            iface = dbus.Interface(kwin_scripting, "org.kde.kwin.Scripting")
            js_path = os.path.join(self.tmp_dir, "scene.js")
            with open(js_path, "w") as f:
                f.write(kwin_js)
            script_id = iface.loadScript(js_path)
            script_obj = bus.get_object("org.kde.KWin", f"/Scripting/Script{script_id}")
            script_iface = dbus.Interface(script_obj, "org.kde.kwin.Script")
            script_iface.run()
            time.sleep(0.5)
        except Exception as e:
            self.log(f"WARN al ejecutar script KWin: {e}")

    def run_demo(self):
        self.setup_env()
        self.start_dbus()
        self.start_kwin()
        self.set_wallpaper_and_dock()

        # Iniciar la grabación de video continua
        self.start_recorder()

        self.log("=== ESCENA 1: Escritorio Tahoe 1:1, NimbusBar 24px y Semáforos exactos ===")
        bar_bin = os.path.join(BIN_DIR, "nimbus-bar")
        qml_root = os.path.join(REPO_ROOT, "packages", "shell", "nimbus-bar", "qml")
        bar_proc = self.spawn([bar_bin, f"--qml-root={qml_root}", "--demo-appmenu"])
        time.sleep(1.5)

        # Abrir Kate / editor con semáforos exactos Tahoe
        kate_proc = self.spawn(["kate"])
        time.sleep(2.0)

        # Colocar Kate centrada con dimensiones estilo macOS
        self.run_scene_script("""
        var wins = workspace.windowList();
        for (var i = 0; i < wins.length; ++i) {
            if (wins[i].caption.indexOf("Kate") !== -1 || wins[i].caption.indexOf("Documento") !== -1) {
                wins[i].frameGeometry = {x: 180, y: 70, width: 1080, height: 680};
                workspace.activeWindow = wins[i];
            }
        }
        """)
        time.sleep(2.5)

        self.log("=== ESCENA 2: Menú Apple / Nimbus y Acerca de Nimbus ===")
        about_bin = os.path.join(BIN_DIR, "nimbus-about")
        about_proc = self.spawn([about_bin])
        time.sleep(1.0)
        self.run_scene_script("""
        var wins = workspace.windowList();
        for (var i = 0; i < wins.length; ++i) {
            if (wins[i].caption.indexOf("Acerca de") !== -1 || wins[i].caption.indexOf("About") !== -1) {
                wins[i].frameGeometry = {x: 480, y: 190, width: 480, height: 460};
                workspace.activeWindow = wins[i];
            }
        }
        """)
        time.sleep(3.5)
        self.stop_proc(about_proc)

        self.log("=== ESCENA 3: Control Center Tahoe con Sliders y Cápsulas 140x64 ===")
        self.stop_proc(bar_proc)
        bar_cc_proc = self.spawn([bar_bin, f"--qml-root={qml_root}", "--open-cc", "--demo-media", "--demo-weather"])
        time.sleep(4.5)

        self.log("=== ESCENA 4: Reloj y Calendario Tahoe (Popover 300x368, Rejilla 6x7) ===")
        self.stop_proc(bar_cc_proc)
        bar_cal_proc = self.spawn([bar_bin, f"--qml-root={qml_root}", "--demo-calendar"])
        time.sleep(4.5)

        self.log("=== ESCENA 5: OSD In-Situ en Barra y Notificaciones Tahoe ===")
        self.stop_proc(bar_cal_proc)
        bar_osd_proc = self.spawn([bar_bin, f"--qml-root={qml_root}", "--demo-osd=volume", "--demo-notification"])
        time.sleep(5.5)
        self.stop_proc(bar_osd_proc)

        # Volver a barra normal para las siguientes aplicaciones
        bar_norm_proc = self.spawn([bar_bin, f"--qml-root={qml_root}", "--demo-appmenu"])
        time.sleep(1.5)

        self.log("=== ESCENA 6: Spotlight Universal Search (Cálculo, Apps, Filtros) ===")
        spotlight_bin = os.path.join(BIN_DIR, "nimbus-spotlight")
        spotlight_proc = self.spawn([spotlight_bin, "--demo", "--query", "calc"])
        time.sleep(4.0)
        self.stop_proc(spotlight_proc)

        self.log("=== ESCENA 7: Apps Tahoe (10 Categorías Fijas, Sugerencias) ===")
        apps_bin = os.path.join(BIN_DIR, "nimbus-apps")
        apps_proc = self.spawn([apps_bin, "--demo"])
        time.sleep(1.0)
        self.run_scene_script("""
        var wins = workspace.windowList();
        for (var i = 0; i < wins.length; ++i) {
            if (wins[i].caption.indexOf("Aplicaciones") !== -1 || wins[i].caption.indexOf("Apps") !== -1) {
                wins[i].frameGeometry = {x: 220, y: 80, width: 1000, height: 680};
                workspace.activeWindow = wins[i];
            }
        }
        """)
        time.sleep(4.0)
        self.stop_proc(apps_proc)

        self.log("=== ESCENA 8: Mission Control y Spaces ===")
        mc_bin = os.path.join(BIN_DIR, "nimbus-missioncontrol")
        mc_proc = self.spawn([mc_bin, "--demo"])
        time.sleep(1.0)
        try:
            bus = dbus.bus.BusConnection(self.dbus_addr)
            mc_obj = bus.get_object("org.nimbus.MissionControl", "/MC")
            mc_iface = dbus.Interface(mc_obj, "org.nimbus.MissionControl")
            mc_iface.show()
        except Exception as e:
            self.log(f"WARN al invocar MC show: {e}")
        time.sleep(4.0)
        self.stop_proc(mc_proc)

        self.stop_proc(kate_proc, name="kate")

        self.log("=== ESCENA 9: Asistente Nimbus Welcome (Onboarding 6 pasos) ===")
        welcome_bin = os.path.join(BIN_DIR, "nimbus-welcome")
        welcome_proc = self.spawn([welcome_bin, "--demo"])
        time.sleep(1.0)
        self.run_scene_script("""
        var wins = workspace.windowList();
        for (var i = 0; i < wins.length; ++i) {
            if ((wins[i].resourceClass && wins[i].resourceClass.indexOf("welcome") !== -1) || wins[i].caption.indexOf("Nimbus") !== -1) {
                wins[i].frameGeometry = {x: 270, y: 90, width: 900, height: 680};
                workspace.activeWindow = wins[i];
            }
        }
        """)
        time.sleep(4.0)
        self.stop_proc(welcome_proc, name="nimbus-welcome")

        self.log("=== ESCENA 10: Ajustes del Sistema Nimbus (KCM 6 Páginas) ===")
        kcm_proc = self.spawn(["kcmshell6", "--caption", "Ajustes del Sistema - Nimbus", "kcm_nimbus"])
        time.sleep(1.5)
        self.run_scene_script("""
        var wins = workspace.windowList();
        for (var i = 0; i < wins.length; ++i) {
            if ((wins[i].resourceClass && (wins[i].resourceClass.indexOf("kcm") !== -1 || wins[i].resourceClass.indexOf("systemsettings") !== -1)) || wins[i].caption.indexOf("Ajustes") !== -1) {
                wins[i].frameGeometry = {x: 240, y: 80, width: 960, height: 700};
                workspace.activeWindow = wins[i];
            }
        }
        """)
        time.sleep(4.5)
        self.stop_proc(kcm_proc, name="kcmshell6")
        self.stop_proc(bar_norm_proc)
        time.sleep(1.0)

        # Detener la grabación
        self.stop_recorder()

        # Extraer fotogramas de evidencia para inspección visual
        self.log("Extrayendo fotogramas de evidencia visual...")
        timestamps = [
            ("01_desktop", "00:00:04.500"),
            ("02_about", "00:00:09.000"),
            ("03_control_center", "00:00:14.000"),
            ("04_calendar", "00:00:19.500"),
            ("05_osd", "00:00:23.000"),
            ("05_osd_notifications", "00:00:26.500"),
            ("06_spotlight", "00:00:31.000"),
            ("07_apps", "00:00:36.000"),
            ("08_mission_control", "00:00:42.000"),
            ("09_welcome", "00:00:48.000"),
            ("10_settings", "00:00:52.000"),
        ]
        for name, ts in timestamps:
            frame_path = os.path.join(FRAMES_DIR, f"frame_{name}.png")
            subprocess.run([
                "ffmpeg", "-y", "-i", OUTPUT_MP4,
                "-ss", ts, "-vframes", "1", "-q:v", "2", frame_path
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        # Generar versión GIF animada ligera para previsualización inmediata
        self.log("Generando GIF animado de previsualización...")
        gif_cmd = [
            "ffmpeg", "-y",
            "-i", OUTPUT_MP4,
            "-vf", "fps=10,scale=720:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer",
            "-t", "55",
            OUTPUT_GIF
        ]
        subprocess.run(gif_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if os.path.isfile(OUTPUT_GIF):
            self.log(f"GIF generado: {OUTPUT_GIF} ({os.path.getsize(OUTPUT_GIF) / 1024 / 1024:.2f} MB)")

    def cleanup(self):
        self.log("Limpiando procesos y archivos temporales...")
        for p in self.managed_procs:
            try:
                p.terminate()
                p.wait(timeout=1)
            except:
                try: p.kill()
                except: pass
        if self.dbus_pid:
            try: os.kill(self.dbus_pid, signal.SIGTERM)
            except: pass
        shutil.rmtree(self.tmp_dir, ignore_errors=True)
        self.log("Limpieza completada.")

if __name__ == "__main__":
    recorder = DemoRecorder()
    try:
        recorder.run_demo()
    finally:
        recorder.cleanup()
