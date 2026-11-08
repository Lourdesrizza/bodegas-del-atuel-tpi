import { pedir, listarVinos, obtenerVino } from "./api.js";

const $ = selector => document.querySelector(selector);
const POR_PAGINA = 12;
const moneda = valor => new Intl.NumberFormat("es-AR", {
  style: "currency", currency: "ARS", minimumFractionDigits: 2,
}).format(Number(valor));
let numeroPagina = 0;
let filtros = {};
let pedidoCatalogo = 0;
let codigoEdicion = null;
let paginaClientes = 0;
let clientesCargados = false;
let salasCargadas = false;
let paginaStock = 0;
let salaStock = null;
let pedidoStock = 0;
const renglonesAgregados = new Map();
const titulos = {
  catalogo: "Catálogo", vino: "Alta y edición", venta: "Nueva venta",
  transferencias: "Transferencias", tablero: "Tablero",
};

// El texto de la API siempre se inserta como texto, nunca como HTML.
function elemento(etiqueta, texto = "", clase = "") {
  const nodo = document.createElement(etiqueta);
  nodo.textContent = texto;
  if (clase) nodo.className = clase;
  return nodo;
}

function mensaje(selector, texto = "", esError = false) {
  const contenedor = $(selector);
  contenedor.textContent = texto;
  contenedor.hidden = !texto;
  contenedor.className = `mensaje${esError ? " error" : ""}`;
  contenedor.setAttribute("role", esError ? "alert" : "status");
}

function vacio(titulo, texto) {
  const contenedor = elemento("div", "", "vacio");
  contenedor.append(elemento("span", "✳"), elemento("h2", titulo), elemento("p", texto));
  return contenedor;
}

async function conBoton(boton, tarea) {
  boton.disabled = true;
  boton.setAttribute("aria-busy", "true");
  try {
    await tarea();
  } finally {
    boton.disabled = false;
    boton.removeAttribute("aria-busy");
  }
}

function tabla(cabeceras, filas) {
  const contenedor = elemento("div", "", "tabla-contenedor");
  const tabla = document.createElement("table");
  const cabeza = tabla.createTHead().insertRow();
  for (const titulo of cabeceras) {
    const celda = elemento("th", titulo);
    celda.scope = "col";
    cabeza.append(celda);
  }
  const cuerpo = tabla.createTBody();
  for (const fila of filas) {
    const renglon = cuerpo.insertRow();
    for (const valor of fila) renglon.append(elemento("td", String(valor)));
  }
  contenedor.append(tabla);
  return contenedor;
}

function cambiarVista() {
  let vista = location.hash.slice(1) || "catalogo";
  if (!titulos[vista]) vista = "catalogo";
  for (const seccion of document.querySelectorAll(".vista")) {
    seccion.hidden = seccion.id !== `vista-${vista}`;
  }
  for (const enlace of document.querySelectorAll("[data-vista]")) {
    if (enlace.dataset.vista === vista) enlace.setAttribute("aria-current", "page");
    else enlace.removeAttribute("aria-current");
  }
  $("#ruta-actual").textContent = titulos[vista];
  document.title = `${titulos[vista]} · Bodegas del Atuel`;
  if (vista === "venta" && !clientesCargados) cargarClientes();
  if (["venta", "transferencias"].includes(vista) && !salasCargadas) cargarSalas();
  if (vista === "tablero") cargarTablero();
  $("#principal").focus({ preventScroll: true });
  window.scrollTo(0, 0);
}

function mostrarVinos(vinos) {
  $("#lista").replaceChildren();
  if (!vinos.length) {
    $("#lista").append(vacio("Una selección por descubrir.", "No hay vinos que coincidan con estos filtros."));
  }
  for (const vino of vinos) {
    const tarjeta = elemento("article", "", "tarjeta");
    const arte = elemento("div", "", `vino-arte ${vino.tipo}`);
    const botella = elemento("span", "", "botella");
    botella.setAttribute("aria-hidden", "true");
    botella.append(document.createElement("i"));
    arte.append(botella, elemento("span", `Nº ${String(vino.cod_vino).padStart(3, "0")}`, "numero-vino"), elemento("span", vino.tipo, "tipo-pill"));
    const cuerpo = elemento("div", "", "tarjeta-cuerpo");
    cuerpo.append(elemento("p", `Añada ${vino.anada} · ${vino.volumen_ml} ml`, "etiqueta"), elemento("h3", vino.nombre), elemento("p", `Bodega · ${vino.cuit_bodega}`, "bodega"));
    const pie = elemento("div", "", "tarjeta-pie");
    const boton = elemento("button", "Ver detalle ↗", "detalle-boton");
    boton.type = "button";
    boton.setAttribute("aria-label", `Ver detalle de ${vino.nombre}`);
    boton.addEventListener("click", () => abrirDetalle(vino.cod_vino));
    pie.append(elemento("span", moneda(vino.precio), "precio"), boton);
    cuerpo.append(pie);
    tarjeta.append(arte, cuerpo);
    $("#lista").append(tarjeta);
  }
}

async function cargarPagina() {
  const pedido = ++pedidoCatalogo;
  mensaje("#catalogo-error");
  $("#catalogo-estado").textContent = "Cargando vinos…";
  $("#anterior").disabled = true;
  $("#siguiente").disabled = true;
  try {
    // La fila adicional permite paginar sin inventar un total general.
    const filas = await listarVinos(filtros, POR_PAGINA + 1, numeroPagina * POR_PAGINA);
    if (pedido !== pedidoCatalogo) return;
    const visibles = filas.slice(0, POR_PAGINA);
    mostrarVinos(visibles);
    $("#pagina").textContent = `Página ${numeroPagina + 1}`;
    $("#catalogo-estado").textContent = `${visibles.length} vinos en esta página`;
    $("#anterior").disabled = numeroPagina === 0;
    $("#siguiente").disabled = filas.length <= POR_PAGINA;
  } catch (fallo) {
    if (pedido !== pedidoCatalogo) return;
    $("#lista").replaceChildren(vacio("Todavía no pudimos encontrarlos.", "Revisá la conexión e intentá filtrar nuevamente."));
    $("#catalogo-estado").textContent = "Catálogo sin conexión";
    mensaje("#catalogo-error", fallo.message, true);
    $("#anterior").disabled = numeroPagina === 0;
  }
}

function listaDetalle(titulo, filas) {
  const seccion = document.createElement("section");
  seccion.append(elemento("h3", titulo));
  const lista = document.createElement("ul");
  for (const fila of filas) lista.append(elemento("li", fila));
  if (!filas.length) lista.append(elemento("li", "Sin datos registrados"));
  seccion.append(lista);
  return seccion;
}

async function abrirDetalle(codigo) {
  mensaje("#catalogo-error");
  try {
    const vino = await obtenerVino(codigo);
    $("#detalle-titulo").textContent = vino.nombre;
    const acciones = elemento("div", "", "detalles-acciones");
    const editar = elemento("button", "Editar esta ficha →", "boton primario");
    editar.addEventListener("click", () => {
      $("#detalle").close();
      location.hash = "vino";
      completarVino(vino);
    });
    acciones.append(editar);
    $("#detalle-contenido").replaceChildren(
      elemento("p", `${vino.tipo} · Añada ${vino.anada} · ${vino.volumen_ml} ml · ${vino.graduacion}°`),
      elemento("p", `Bodega ${vino.cuit_bodega} · ${moneda(vino.precio)}`),
      listaDetalle("Composición", vino.cepas.map(c => `${c.nombre} · ${c.porcentaje} %`)),
      listaDetalle("Maridajes", vino.maridajes.map(m => `${m.nombre} · ${m.temperatura_servicio} °C`)),
      acciones,
    );
    $("#detalle").showModal();
  } catch (fallo) {
    mensaje("#catalogo-error", fallo.message, true);
  }
}

// Estos renglones reúnen datos de entrada. Los importes se calculan en PostgreSQL.
function agregarRenglon(contenedor, esCorte = false, valores = {}) {
  const fila = elemento("div", "", "renglon-form");
  const campoId = elemento("label", esCorte ? "Cepa · ID" : "Vino · código");
  const id = document.createElement("input");
  id.type = "number";
  id.min = "1";
  id.max = "2147483647";
  id.required = true;
  id.dataset.campo = "id";
  id.value = valores.id ?? "";
  campoId.append(id);
  const campoValor = elemento("label", esCorte ? "Porcentaje" : "Botellas");
  const valor = document.createElement("input");
  valor.type = "number";
  valor.min = esCorte ? "0.01" : "1";
  valor.max = esCorte ? "100" : "2147483647";
  valor.step = esCorte ? "0.01" : "1";
  valor.required = true;
  valor.dataset.campo = "valor";
  valor.value = valores.valor ?? "";
  campoValor.append(valor);
  const quitar = elemento("button", "×", "quitar");
  quitar.type = "button";
  quitar.setAttribute("aria-label", esCorte ? "Quitar cepa" : "Quitar vino");
  quitar.addEventListener("click", () => {
    if ($(contenedor).children.length > 1) fila.remove();
    else { id.value = ""; valor.value = ""; id.focus(); }
  });
  fila.append(campoId, campoValor, quitar);
  $(contenedor).append(fila);
}

function leerRenglones(selector, esCorte = false) {
  return Array.from($(selector).children, fila => {
    const id = Number(fila.querySelector('[data-campo="id"]').value);
    const valor = fila.querySelector('[data-campo="valor"]').value;
    return esCorte ? { id_cepa: id, porcentaje: valor } : { cod_vino: id, cantidad: Number(valor) };
  });
}

function completarVino(vino) {
  codigoEdicion = vino.cod_vino;
  for (const nombre of ["nombre", "cuit_bodega", "tipo", "anada", "volumen_ml", "graduacion", "precio"]) {
    $("#form-vino").elements[nombre].value = vino[nombre];
  }
  $("#form-vino").elements.maridajes.value = vino.maridajes.map(m => m.id_maridaje).join(", ");
  $("#cortes").replaceChildren();
  for (const corte of vino.cepas) agregarRenglon("#cortes", true, { id: corte.id_cepa, valor: corte.porcentaje });
  if (!vino.cepas.length) agregarRenglon("#cortes", true);
  $("#modo-vino").textContent = `Editando vino Nº ${vino.cod_vino}`;
  $("#guardar-vino").textContent = "Guardar cambios →";
  mensaje("#vino-mensaje");
}

function nuevoVino() {
  codigoEdicion = null;
  $("#form-vino").reset();
  $("#cortes").replaceChildren();
  agregarRenglon("#cortes", true);
  $("#modo-vino").textContent = "Nueva etiqueta";
  $("#guardar-vino").textContent = "Guardar vino →";
  mensaje("#vino-mensaje");
}

async function guardarVino(evento) {
  evento.preventDefault();
  await conBoton($("#guardar-vino"), async () => {
    mensaje("#vino-mensaje");
    const datos = Object.fromEntries(new FormData(evento.currentTarget));
    datos.anada = Number(datos.anada);
    datos.volumen_ml = Number(datos.volumen_ml);
    datos.cepas = leerRenglones("#cortes", true);
    datos.maridajes = datos.maridajes.trim() ? datos.maridajes.split(",").map(id => Number(id.trim())) : [];
    try {
      const vino = await pedir(codigoEdicion ? `/vinos/${codigoEdicion}` : "/vinos", codigoEdicion ? "PUT" : "POST", datos);
      completarVino(vino);
      mensaje("#vino-mensaje", `Vino Nº ${vino.cod_vino} guardado correctamente.`);
      cargarPagina();
    } catch (fallo) {
      mensaje("#vino-mensaje", fallo.message, true);
    }
  });
}

async function cargarClientes() {
  $("#clientes-anterior").disabled = true;
  $("#clientes-siguiente").disabled = true;
  $("#venta-cliente").disabled = true;
  mensaje("#venta-mensaje");
  try {
    const filas = await pedir(`/clientes?limite=26&offset=${paginaClientes * 25}`);
    const opciones = [elemento("option", "Elegí un cliente")];
    opciones[0].value = "";
    for (const cliente of filas.slice(0, 25)) {
      const opcion = elemento("option", `${cliente.nombre_o_razon_social} · ${cliente.tipo_cliente} · Nº ${cliente.id_cliente}`);
      opcion.value = cliente.id_cliente;
      opciones.push(opcion);
    }
    $("#venta-cliente").replaceChildren(...opciones);
    $("#clientes-pagina").textContent = `Página ${paginaClientes + 1}`;
    $("#clientes-siguiente").disabled = filas.length <= 25;
    clientesCargados = true;
  } catch (fallo) {
    mensaje("#venta-mensaje", fallo.message, true);
    const opcion = elemento("option", "No se pudieron cargar los clientes");
    opcion.value = "";
    $("#venta-cliente").replaceChildren(opcion);
    $("#clientes-siguiente").disabled = false;
  } finally {
    $("#venta-cliente").disabled = false;
    $("#clientes-anterior").disabled = paginaClientes === 0;
  }
}

function mostrarComprobante(comprobante) {
  $(".nota-rosa").textContent = "Último comprobante registrado en esta pantalla.";
  const recibo = elemento("section", "", "recibo");
  recibo.append(elemento("h3", `Comprobante Nº ${comprobante.nro_comprobante}`), elemento("p", `Sala ${comprobante.id_sala} · ${comprobante.fecha}`));
  recibo.append(tabla(["Vino", "Botellas", "Neto"], comprobante.renglones.map(r => [r.cod_vino, r.cantidad, moneda(r.subtotal_renglon)])));
  const importes = document.createElement("dl");
  for (const [nombre, valor] of [["Subtotal", comprobante.subtotal], ["Descuento", comprobante.descuento], ["Total", comprobante.total]]) {
    const etiqueta = elemento("dt", nombre);
    const importe = elemento("dd", moneda(valor));
    if (nombre === "Total") { etiqueta.className = "total-recibo"; importe.className = "total-recibo"; }
    importes.append(etiqueta, importe);
  }
  recibo.append(importes);
  $("#venta-resultado").replaceChildren(recibo);
}

async function registrarVenta(evento) {
  evento.preventDefault();
  const formulario = evento.currentTarget;
  await conBoton($("#registrar-venta"), async () => {
    mensaje("#venta-mensaje");
    const datos = {
      id_cliente: Number(formulario.elements.id_cliente.value),
      id_sala: Number(formulario.elements.id_sala.value),
      renglones: leerRenglones("#venta-renglones"),
    };
    try {
      const comprobante = await pedir("/comprobantes", "POST", datos);
      mostrarComprobante(comprobante);
      mensaje("#venta-mensaje", `Venta registrada. Comprobante Nº ${comprobante.nro_comprobante}.`);
      // Vaciar sólo los vinos evita repetir la venta con un segundo clic.
      $("#venta-renglones").replaceChildren();
      agregarRenglon("#venta-renglones");
    } catch (fallo) {
      mensaje("#venta-mensaje", fallo.message, true);
    }
  });
}

function mostrarTransferencia(documento) {
  const contenedor = $("#transferencia-detalle");
  const cabecera = elemento("div", "", "fila-estado");
  const nombres = { en_confeccion: "En confección", terminado: "Terminada", procesado: "Procesada" };
  cabecera.append(elemento("h2", `Solicitud Nº ${documento.nro_solicitud}`), elemento("span", nombres[documento.estado], "estado-pill"));
  const pasos = elemento("ol", "", "pasos");
  for (const estado of Object.keys(nombres)) pasos.append(elemento("li", nombres[estado], estado === documento.estado ? "activo" : ""));
  contenedor.replaceChildren(cabecera, elemento("p", `Sala ${documento.id_sala} · ${documento.fecha_confeccion}`, "ayuda"), pasos);
  const filas = renglonesAgregados.get(documento.nro_solicitud) ?? [];
  contenedor.append(elemento("h3", "Renglones agregados en esta sesión"));
  if (filas.length) contenedor.append(tabla(["Vino", "Botellas"], filas.map(r => [r.cod_vino, r.cantidad])));
  else contenedor.append(elemento("p", "Todavía no agregaste vinos desde esta pantalla.", "ayuda"));
  const formulario = document.createElement("form");
  formulario.id = "renglon-transferencia";
  const campos = elemento("div");
  campos.id = "transferencia-campos";
  formulario.append(campos);
  contenedor.append(formulario);
  agregarRenglon("#transferencia-campos");
  // El renglón de transferencia se envía individualmente.
  campos.querySelector(".quitar").remove();
  const agregar = elemento("button", "＋ Agregar renglón", "boton secundario");
  formulario.append(agregar);
  for (const campo of formulario.elements) campo.disabled = documento.estado !== "en_confeccion";
  formulario.addEventListener("submit", async evento => {
    evento.preventDefault();
    await conBoton(agregar, async () => {
      mensaje("#transferencia-mensaje");
      try {
        const fila = leerRenglones("#transferencia-campos")[0];
        const guardada = await pedir(`/transferencias/${documento.nro_solicitud}/renglones`, "POST", fila);
        filas.push(guardada);
        renglonesAgregados.set(documento.nro_solicitud, filas);
        mostrarTransferencia(documento);
        mensaje("#transferencia-mensaje", "Renglón agregado a la solicitud.");
      } catch (fallo) { mensaje("#transferencia-mensaje", fallo.message, true); }
    });
  });
  const acciones = elemento("div", "", "acciones-documento");
  for (const [accion, etiqueta, estado] of [["terminar", "Terminar solicitud", "en_confeccion"], ["procesar", "Procesar traslado →", "terminado"]]) {
    const boton = elemento("button", etiqueta, accion === "procesar" ? "boton primario" : "boton secundario");
    boton.type = "button";
    boton.disabled = documento.estado !== estado;
    boton.addEventListener("click", () => cambiarEstado(boton, accion, documento));
    acciones.append(boton);
  }
  contenedor.append(acciones);
}

async function cambiarEstado(boton, accion, documento) {
  await conBoton(boton, async () => {
    mensaje("#transferencia-mensaje");
    try {
      const actualizado = await pedir(`/transferencias/${documento.nro_solicitud}/${accion}`, "POST");
      mostrarTransferencia(actualizado);
      mensaje("#transferencia-mensaje", accion === "procesar" ? "Transferencia procesada correctamente." : "Solicitud terminada. Ya podés procesar el traslado.");
    } catch (fallo) { mensaje("#transferencia-mensaje", fallo.message, true); }
  });
}

async function cargarSalas() {
  try {
    const filas = await pedir("/reportes/ventas-por-sala");
    $("#salas").replaceChildren(...filas.map(sala => {
      const opcion = elemento("option", `Sala ${sala.id_sala}`);
      opcion.value = sala.id_sala;
      return opcion;
    }));
    salasCargadas = true;
  } catch { /* Los códigos de sala se pueden ingresar manualmente. */ }
}

async function cargarRanking() {
  $("#ranking").replaceChildren(elemento("p", "Cargando ranking…", "ayuda"));
  try {
    const filas = await pedir("/reportes/top-vinos");
    $("#ranking").replaceChildren();
    if (!filas.length) $("#ranking").append(vacio("El primer brindis está por llegar.", "Aún no hay ventas registradas."));
    filas.forEach((vino, indice) => {
      const fila = elemento("div", "", "ranking-fila");
      const cantidad = elemento("div", String(vino.botellas));
      cantidad.append(elemento("small", " botellas"));
      fila.append(elemento("span", String(indice + 1).padStart(2, "0"), "posicion"), elemento("span", vino.nombre), cantidad);
      $("#ranking").append(fila);
    });
  } catch (fallo) { $("#ranking").replaceChildren(elemento("p", fallo.message, "mensaje error")); }
}

async function cargarGrafico() {
  $("#grafico").replaceChildren(elemento("p", "Cargando ventas…", "ayuda"));
  try {
    const filas = await pedir("/reportes/ventas-por-sala");
    $("#grafico").replaceChildren();
    if (!filas.length) $("#grafico").append(vacio("Sin salas para mostrar.", "Las ventas aparecerán al registrar actividad."));
    // Sólo se escala la longitud visual. Los importes provienen de la API.
    const maximo = Math.max(1, ...filas.map(fila => Number(fila.total)));
    for (const sala of filas) {
      const fila = elemento("div", "", "barra-fila");
      const leyenda = elemento("div", "", "barra-leyenda");
      leyenda.append(elemento("span", `Sala ${sala.id_sala}`), elemento("span", moneda(sala.total)));
      const pista = elemento("div", "", "barra-pista");
      pista.setAttribute("aria-hidden", "true");
      const barra = elemento("div", "", "barra-valor");
      barra.style.width = `${Number(sala.total) / maximo * 100}%`;
      pista.append(barra);
      fila.append(leyenda, pista);
      $("#grafico").append(fila);
    }
  } catch (fallo) { $("#grafico").replaceChildren(elemento("p", fallo.message, "mensaje error")); }
}

async function cargarTablero() {
  await conBoton($("#actualizar-tablero"), async () => {
    await Promise.all([cargarRanking(), cargarGrafico()]);
  });
}

async function cargarStock() {
  const pedido = ++pedidoStock;
  $("#stock-anterior").disabled = true;
  $("#stock-siguiente").disabled = true;
  $("#stock-resultado").replaceChildren(elemento("p", "Consultando disponibilidad…", "ayuda"));
  try {
    const filas = await pedir(`/reportes/vinos-sin-stock?sala=${salaStock}&limite=13&offset=${paginaStock * 12}`);
    if (pedido !== pedidoStock) return;
    const visibles = filas.slice(0, 12);
    $("#stock-resultado").replaceChildren(visibles.length ? tabla(["Código", "Vino", "En depósito"], visibles.map(v => [v.cod_vino, v.nombre, v.cantidad])) : vacio("Sin faltantes para mostrar.", "No se encontraron vinos sin stock en esta consulta."));
    $("#stock-paginas").hidden = false;
    $("#stock-pagina").textContent = `Página ${paginaStock + 1}`;
    $("#stock-anterior").disabled = paginaStock === 0;
    $("#stock-siguiente").disabled = filas.length <= 12;
  } catch (fallo) {
    if (pedido !== pedidoStock) return;
    $("#stock-resultado").replaceChildren(elemento("p", fallo.message, "mensaje error"));
    $("#stock-paginas").hidden = true;
  }
}

$("#filtros").addEventListener("submit", evento => {
  evento.preventDefault();
  filtros = Object.fromEntries(new FormData(evento.currentTarget));
  numeroPagina = 0;
  cargarPagina();
});
$("#filtros").addEventListener("reset", () => {
  filtros = {}; numeroPagina = 0; queueMicrotask(cargarPagina);
});
$("#anterior").addEventListener("click", () => { numeroPagina--; cargarPagina(); });
$("#siguiente").addEventListener("click", () => { numeroPagina++; cargarPagina(); });
$("#cerrar").addEventListener("click", () => $("#detalle").close());
$("#nuevo-vino").addEventListener("click", nuevoVino);
$("#agregar-cepa").addEventListener("click", () => agregarRenglon("#cortes", true));
$("#agregar-venta").addEventListener("click", () => agregarRenglon("#venta-renglones"));
$("#form-vino").addEventListener("submit", guardarVino);
$("#form-venta").addEventListener("submit", registrarVenta);
$("#clientes-anterior").addEventListener("click", () => { paginaClientes--; cargarClientes(); });
$("#clientes-siguiente").addEventListener("click", () => { paginaClientes++; cargarClientes(); });
$("#buscar-edicion").addEventListener("submit", async evento => {
  evento.preventDefault();
  const codigo = evento.currentTarget.elements.codigo.value;
  await conBoton(evento.submitter, async () => {
    try { completarVino(await obtenerVino(codigo)); }
    catch (fallo) { mensaje("#vino-mensaje", fallo.message, true); }
  });
});
$("#crear-transferencia").addEventListener("submit", async evento => {
  evento.preventDefault();
  const sala = Number(evento.currentTarget.elements.id_sala.value);
  await conBoton(evento.submitter, async () => {
    mensaje("#transferencia-mensaje");
    try {
      const documento = await pedir("/transferencias", "POST", { id_sala: sala });
      mostrarTransferencia(documento);
      mensaje("#transferencia-mensaje", `Solicitud Nº ${documento.nro_solicitud} creada.`);
    } catch (fallo) { mensaje("#transferencia-mensaje", fallo.message, true); }
  });
});
$("#buscar-transferencia").addEventListener("submit", async evento => {
  evento.preventDefault();
  const codigo = evento.currentTarget.elements.codigo.value;
  await conBoton(evento.submitter, async () => {
    mensaje("#transferencia-mensaje");
    try { mostrarTransferencia(await pedir(`/transferencias/${codigo}`)); }
    catch (fallo) { mensaje("#transferencia-mensaje", fallo.message, true); }
  });
});
$("#actualizar-tablero").addEventListener("click", cargarTablero);
$("#buscar-stock").addEventListener("submit", evento => {
  evento.preventDefault();
  salaStock = Number(evento.currentTarget.elements.sala.value);
  paginaStock = 0;
  cargarStock();
});
$("#stock-anterior").addEventListener("click", () => { paginaStock--; cargarStock(); });
$("#stock-siguiente").addEventListener("click", () => { paginaStock++; cargarStock(); });
window.addEventListener("hashchange", cambiarVista);
nuevoVino();
agregarRenglon("#venta-renglones");
cargarPagina();
cambiarVista();
