import { API_BASE_URL } from "./config.js";

export async function pedir(ruta, metodo = "GET", cuerpo = undefined) {
  let respuesta;
  try {
    respuesta = await fetch(`${API_BASE_URL}${ruta}`, {
      method: metodo,
      headers: {
        Accept: "application/json",
        ...(metodo === "GET" ? {} : { "Content-Type": "application/json" }),
      },
      body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
    });
  } catch {
    throw new Error("No se pudo conectar con la API.");
  }

  const datos = await respuesta.json().catch(() => null);
  if (!respuesta.ok) {
    // La API envía el mensaje de la regla en detail. Se presenta sin sustituirlo.
    const detalle = datos?.detail;
    throw new Error(typeof detalle === "string" ? detalle : JSON.stringify(detalle ?? datos ?? `HTTP ${respuesta.status}`));
  }
  return datos;
}

export function listarVinos(filtros, limite, offset) {
  const parametros = new URLSearchParams();
  for (const [nombre, valor] of Object.entries(filtros)) {
    if (valor !== "") parametros.set(nombre, valor);
  }
  parametros.set("limite", String(limite));
  parametros.set("offset", String(offset));
  return pedir(`/vinos?${parametros}`);
}

export function obtenerVino(codigo) {
  return pedir(`/vinos/${encodeURIComponent(codigo)}`);
}
