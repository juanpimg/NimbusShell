.pragma library

// I18n.js — cadenas del wizard F9-T02 (es fuente, en traducido).
// Preparado para ki18n/.ts (F11-T05): cada clave es la cadena fuente
// completa en español, sin concatenar frases; tr() cae a la fuente.
var _lang = "es";

var dicts = {
    "en": {
        "Te damos la bienvenida a Nimbus": "Welcome to Nimbus",
        "Un escritorio familiar, rápido y tuyo. Este asistente te deja todo listo en menos de 5 minutos.": "A familiar, fast desktop of your own. This assistant gets everything ready in under 5 minutes.",
        "Idioma": "Language",
        "Elige tu idioma. Se aplicará a todo el sistema.": "Choose your language. It will apply to the whole system.",
        "Español": "Spanish",
        "Inglés": "English",
        "Wi-Fi": "Wi-Fi",
        "Conéctate para terminar de configurar el sistema. Puedes omitir este paso.": "Connect to finish setting up the system. You may skip this step.",
        "Buscar redes": "Scan networks",
        "Contraseña": "Password",
        "Conectar": "Connect",
        "Tu cuenta": "Your account",
        "¿Cómo te llamas? Tu nombre aparece en el menú y la pantalla de bloqueo.": "What is your name? It shows in the menu and the lock screen.",
        "Tu nombre": "Your name",
        "Elegir foto…": "Choose photo…",
        "Apariencia": "Appearance",
        "Claro u oscuro y tu color de acento. Se aplica con nimbus-theme.": "Light or dark and your accent color. Applied with nimbus-theme.",
        "Claro": "Light",
        "Oscuro": "Dark",
        "Color de acento": "Accent color",
        "Aplicar": "Apply",
        "Apps recomendadas": "Recommended apps",
        "Marca las que quieras descubrir. No se instala nada ahora: las verás en Descubrir.": "Tick the ones you want to explore. Nothing is installed now: you will find them in Discover.",
        "Listo para despegar": "Ready to go",
        "Ya está todo. Este es tu escritorio Nimbus: menú arriba, Dock abajo, Spotlight con Cmd+Espacio.": "All set. This is your Nimbus desktop: menu on top, Dock at the bottom, Spotlight with Cmd+Space.",
        "Atrás": "Back",
        "Siguiente": "Next",
        "Omitir": "Skip",
        "Terminar": "Finish",
        "de": "of"
    }
};

function setLang(code) {
    _lang = (code === "en") ? "en" : "es";
}

function code() {
    return _lang;
}

function tr(text) {
    if (_lang === "es" || typeof text !== "string")
        return text;
    var d = dicts[_lang];
    if (!d)
        return text;
    var t = d[text];
    return (t !== undefined) ? t : text;
}
