# RHOIDS App Store Listing — Spanish (es)

Neutral international Spanish, suitable for both Latin America and Spain. Register:
informal "tú", matching the tone already used throughout the in-app Spanish
localization (see `Sources/Localizable.xcstrings`). Terminology (temporizador,
bloquear/bloqueado, racha, enfriamiento, etc.) matches the in-app catalog so App Store
copy and product UI use the same vocabulary.

Locale code to use in App Store Connect: `es-ES` (Spanish - Spain) as the base Spanish
listing, or `es-419`/`es-MX` if Apple's App Store Connect locale picker is used for a
Latin-America-specific listing. See the note at the bottom on locale variants.

## App Name
RHOIDS - Temporizador de baño

## Subtitle (30 chars max)
Temporizador con base científica

(29 characters — fits the 30-character limit.)

## Promotional Text (170 chars max, can update without new build)
Deja de perder el tiempo en el baño. RHOIDS es un temporizador de baño centrado en la privacidad, basado en investigación médica publicada.

## Description

RHOIDS es un temporizador de baño centrado en la privacidad que te ayuda a dejar de hacer scroll en el baño y a mantener las pausas cortas.

Las sesiones largas en el baño son uno de los hábitos más fáciles de ignorar. También son de los más sencillos de cambiar. RHOIDS te da una cuenta atrás clara, un punto de corte definido y recordatorios persistentes en iPhone y Apple Watch para que sepas cuándo levantarte.

Diseñado a partir de investigación publicada y guías clínicas, RHOIDS mantiene la experiencia enfocada: sin panel de bienestar, sin feed social, sin cuenta que crear, sin anuncios y sin rastreo. Solo un temporizador de baño rápido, pensado para una única tarea.

POR QUÉ USAR UN TEMPORIZADOR DE BAÑO

Un estudio de 2025 de Harvard Medical School y Beth Israel Deaconess, publicado en PLOS One, relacionó el uso del teléfono en el baño con un riesgo un 46 % mayor de hemorroides. El mismo estudio encontró que el 37 % de las personas que usaban el teléfono pasaban más de cinco minutos por visita al baño.

RHOIDS convierte esa investigación en un hábito diario sencillo: inicia el temporizador, termina y sal.

QUÉ INCLUYE

- Temporizador recomendado: un ajuste de 3 minutos para pausas rápidas
- Temporizador máximo: un límite de 5 minutos basado en pautas médicas habituales
- Temporizador personalizado: elige tu propia duración cuando necesites flexibilidad
- Actividad en directo: consulta el tiempo restante en la pantalla de bloqueo y en la Dynamic Island
- Widgets: inicia un temporizador de baño desde la pantalla de inicio o la pantalla de bloqueo
- Apple Watch: sigue la cuenta atrás con hápticos y complicaciones
- Atajos de Siri: inicia y detén temporizadores con la voz
- Focus Lock: bloquea las apps que elijas al terminar el temporizador
- Historial local: revisa tus sesiones recientes sin enviar datos a ningún sitio

PENSADO PARA LA PRIVACIDAD

RHOIDS está diseñado para un hábito privado, así que se mantiene privado.

- Sin cuentas
- Sin rastreo
- Sin anuncios
- Sin funciones sociales
- Sin dependencias de terceros
- El historial de sesiones se queda en tu dispositivo

CIENCIA SIN COMPLICACIONES

RHOIDS incluye una sección "Ciencia" dentro de la app con la investigación detrás de los temporizadores, incluido el estudio de PLOS One de 2025 sobre el uso del teléfono, investigación más amplia sobre la prevalencia de las hemorroides y orientación de fuentes médicas reconocidas. El objetivo no es asustarte ni convertir las pausas en el baño en una métrica más de fitness. El objetivo es facilitar la repetición de un hábito saludable.

RHOIDS es un temporizador de comportamiento, no un dispositivo ni un tratamiento médico. Si tienes sangrado, dolor, síntomas persistentes o cualquier duda médica, consulta con un profesional de la salud cualificado.

Descarga RHOIDS y crea el hábito de baño más sencillo: inicia el temporizador, deja de hacer scroll y sal del baño a tiempo.

## Keywords (100 chars max, comma-separated)
hemorroides,intestino,baño,pantalla,tiempo,cronómetro,límite,bloqueo,recordatorio,alerta,dolor,ibs

(Adapted, not a literal translation, to target Spanish-language App Store search terms
directly — literal translations of the English keyword list would waste characters on
low-value terms.)

## Categories
Primary: Salud y forma física (Health & Fitness)
Secondary: Medicina (Medical)

## Content Rating
4+ (Sin contenido objetable)

## Privacy URL
(Same requirement as the English listing: host the repository privacy policy at a
public URL. Apple does not require a separately translated privacy policy for the
Spanish store listing, but a Spanish version is recommended — see notes below.)

## Copyright
© 2026 Wesley Keetch

---

## What's New template (es)

Use this structure for release notes; keep entries short and match the tone of the
English "What's New" for the same build.

Ejemplo:
"Mejoras de estabilidad y correcciones menores."

---

## Regional / locale notes (not a code change — product/App Store Connect decisions)

- **Locale variant to submit**: App Store Connect's Spanish locales are `es-ES` (Spain),
  `es-MX` (Mexico), and the in-app `es-419` fallback used by iOS itself for other
  Latin American countries. Apple does **not** offer a single "Spanish (Latin America)"
  App Store Connect listing locale — you must pick `es-ES` and/or `es-MX` as actual
  App Store Connect metadata locales. The copy above is written in neutral
  international Spanish and is safe to submit as the `es-ES` listing; it will also read
  naturally to `es-MX`/LatAm users. Only add a separate `es-MX` App Store Connect
  listing if you want Mexico-specific keywords, pricing, or promotional text — not
  required for correctness.
- **Screenshots**: the existing screenshot pipeline (`scripts/frame_screenshots_v2.py`,
  `AppStore/Screenshots/`) produces English-captioned marketing screenshots. Spanish
  App Store listings need their own captioned screenshot set (same device frames, translated
  caption text) before this listing can be considered complete for submission — that's a
  screenshot-pipeline task, not a code change, and is not included in this pass.
  See the `app-store-screenshots` skill for the localized-screenshot workflow.
- **Pricing/availability/tax**: unaffected by adding a Spanish listing — App Store
  pricing and territory availability are configured independently in App Store Connect
  and are unchanged by this work.
- **Legal/support**: the app's support and privacy-policy URLs are not currently
  Spanish-localized (out of scope for this pass — flagged for product/legal review).
  Apple does not require translated legal pages to ship a translated listing, but it's
  good practice for a fully localized experience.
