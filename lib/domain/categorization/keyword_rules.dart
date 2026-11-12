import '../entities/category.dart';

class KeywordRule {
  const KeywordRule(this.categoryId, this.keywords);

  final String categoryId;

  /// Palabras clave en MAYÚSCULAS sin tildes (formato de `TextTools.merchantKey`).
  /// Se comparan como prefijo de palabra: `EXITO` cubre `EXITO CALLE 80`.
  final List<String> keywords;
}

/// Reglas por defecto con comercios frecuentes en Colombia. El orden importa:
/// la primera regla que coincide gana (por eso UBER EATS va antes que UBER).
const List<KeywordRule> defaultKeywordRules = [
  KeywordRule(_restaurantes, [
    'UBER EATS', 'UBER  EATS', 'UBEREATS', 'DIDI FOOD', 'DIDIFOOD', 'RAPPI',
    'IFOOD', 'MCDONALD', 'MC DONALD', 'MCD ', 'BURGER KING', 'KFC', 'SUBWAY',
    'CREPES', 'FRISBY', 'KOKORIKO', 'EL CORRAL', 'CORRAL', 'PRESTO', 'DOMINO',
    'PAPA JOHN', 'PIZZA', 'JUAN VALDEZ', 'STARBUCKS', 'TOSTAO', 'OMA ',
    'DUNKIN', 'WOK', 'SUSHI', 'RESTAURANTE', 'REST ', 'RESTO ', 'CAFE',
    'CAFETERIA', 'PANADERIA', 'HAMBURGUES', 'POLLO', 'ASADERO', 'COMIDAS',
    'FOOD', 'BURGER', 'TACOS', 'AREPA', 'EMPANADA', 'HELADO', 'CREPE',
    'POPSY', 'MIMOS', 'BUFFALO', 'SIERRA NEVADA', 'HOME BURGER', 'SANDWICH',
    'QBANO', 'ARCHIES', 'LA LUCHA', 'DOMICILIO',
  ]),
  KeywordRule(_mercado, [
    'EXITO', 'CARULLA', 'D1 ', 'D1', 'TIENDAS D1', 'ARA ', 'ARA', 'JUMBO',
    'OLIMPICA', 'METRO ', 'MAKRO', 'PRICESMART', 'SURTIMAX', 'SUPER INTER',
    'SURTI', 'EURO ', 'COLSUBSIDIO', 'CAFAM', 'MERCADO', 'SUPERMERCADO',
    'FRUVER', 'JUSTO Y BUENO', 'JUSTO Y', 'ZAPATOCA', 'LA 14', 'CANAVERAL',
    'MERCAMAS', 'MERQUEO', 'FARMATODO MERCADO', 'MINIMERCADO', 'TIENDA ',
    'ALMACENES EXITO', 'CENCOSUD', 'COORATIENDAS', 'LA VAQUITA', 'CONSUMO',
  ]),
  KeywordRule(_transporte, [
    'UBER', 'DIDI', 'CABIFY', 'INDRIVE', 'INDRIVER', 'BEAT', 'PICAP',
    'TRANSMILENIO', 'TULLAVE', 'TU LLAVE', 'SITP', 'METRO DE MEDELLIN',
    'METRO CALI', 'MIO ', 'TERPEL', 'PRIMAX', 'TEXACO', 'ESSO', 'MOBIL',
    'BIOMAX', 'PETROBRAS', 'ZEUSS', 'EDS ', 'ESTACION', 'GASOLINA',
    'COMBUSTIBLE', 'PEAJE', 'FLYPASS', 'PARQUEADERO', 'PARKING', 'TAXI',
    'MOTO', 'LAVADERO', 'SOAT', 'TECNOMECANICA',
  ]),
  KeywordRule(_suscripciones, [
    'NETFLIX', 'SPOTIFY', 'DISNEY', 'HBO', 'MAX ', 'AMAZON PRIME',
    'PRIME VIDEO', 'YOUTUBE', 'GOOGLE ONE', 'GOOGLE STORAGE', 'APPLE COM',
    'APPLE BILL', 'ITUNES', 'ICLOUD', 'MICROSOFT', 'OPENAI', 'CHATGPT',
    'ANTHROPIC', 'CLAUDE', 'PARAMOUNT', 'CRUNCHYROLL', 'DEEZER', 'CANVA',
    'ADOBE', 'DROPBOX', 'PLAYSTATION PLUS', 'XBOX GAME PASS', 'NINTENDO',
    'GOOGLE PLAY', 'GOOGLE ', 'AUDIBLE', 'KINDLE', 'NOTION', 'FIGMA',
    'GITHUB', 'DUOLINGO PLUS', 'STRAVA', 'TINDER', 'BUMBLE', 'TWITCH',
    'VIX', 'WIN SPORTS', 'DAZN',
  ]),
  KeywordRule(_hogar, [
    'CLARO', 'MOVISTAR', 'TIGO', 'WOM', 'ETB', 'DIRECTV', 'EPM', 'ENEL',
    'CODENSA', 'VANTI', 'ACUEDUCTO', 'EAAB', 'EMCALI', 'AGUAS', 'GAS NATURAL',
    'GASES', 'AIRE ', 'AIR E', 'ELECTRICARIBE', 'CELSIA', 'EMPRESAS PUBLICAS',
    'ESSA', 'EFIGAS', 'SURTIGAS', 'ADMINISTRACION', 'ARRIENDO', 'ALQUILER',
    'HOMECENTER', 'SODIMAC', 'IKEA', 'FACTURA', 'SERVICIO PUBLICO',
    'SERVICIOS PUBLICOS', 'INTERNET', 'CELULAR', 'RECARGA', 'FERRETERIA',
    'EASY ', 'CONJUNTO', 'LAVANDERIA', 'ASEO', 'HIPOTECA', 'CREDITO DE VIVIENDA',
  ]),
  KeywordRule(_salud, [
    'FARMATODO', 'CRUZ VERDE', 'LA REBAJA', 'DROGUERIA', 'DROGAS', 'FARMACIA',
    'COLSANITAS', 'SANITAS', 'SURA', 'COMPENSAR', 'EPS', 'CLINICA', 'HOSPITAL',
    'MEDICO', 'ODONTOLOG', 'LABORATORIO', 'OPTICA', 'PASTEUR', 'COLMEDICA',
    'MEDIMAS', 'AUDIFARMA', 'LOCATEL', 'VETERINARIA', 'PSICOLOG', 'TERAPIA',
    'DENTIX', 'ALLIANZ', 'SEGUROS BOLIVAR', 'MAPFRE',
  ]),
  KeywordRule(_compras, [
    'FALABELLA', 'ZARA', 'H M', 'H&M', 'ARTURO CALLE', 'ADIDAS', 'NIKE',
    'MERCADOLIBRE', 'MERCADO LIBRE', 'MELI', 'AMAZON', 'TEMU', 'SHEIN',
    'ALIEXPRESS', 'ALKOSTO', 'KTRONIX', 'PANAMERICANA', 'KOAJ', 'STUDIO F',
    'VELEZ', 'TOTTO', 'BERSHKA', 'PULL BEAR', 'PULL&BEAR', 'STRADIVARIUS',
    'DOLLARCITY', 'MINISO', 'LINIO', 'DAFITI', 'PEPE GANGA', 'OFFCORSS',
    'CENTRO COMERCIAL', 'UNICENTRO', 'ANDINO', 'SANTAFE', 'TITAN PLAZA',
    'ELA ', 'GEF', 'PUNTO BLANCO', 'LEONISA', 'BOSI', 'SPRING STEP', 'CROCS',
    'DECATHLON', 'MAC CENTER', 'ISHOP', 'SAMSUNG', 'XIAOMI', 'JUMBO TECNO',
    'CUERON', 'JOYERIA', 'PERFUMERIA', 'LIBRERIA NACIONAL',
  ]),
  KeywordRule(_educacion, [
    'UNIVERSIDAD', 'UNIV ', 'COLEGIO', 'PLATZI', 'UDEMY', 'COURSERA',
    'DOMESTIKA', 'CURSO', 'MATRICULA', 'ICETEX', 'LIBRERIA', 'DUOLINGO',
    'ACADEMIA', 'INSTITUTO', 'SENA', 'PENSION', 'PRUEBAS', 'CAPACITACION',
    'OPEN ENGLISH', 'SMART ', 'BERLITZ',
  ]),
  KeywordRule(_viajes, [
    'AVIANCA', 'LATAM', 'WINGO', 'VIVA AIR', 'JETSMART', 'AIRBNB', 'BOOKING',
    'DESPEGAR', 'HOTEL', 'HOSTAL', 'EXPEDIA', 'TRIVAGO', 'COPA AIR',
    'AEROPUERTO', 'TIQUETES', 'TERMINAL', 'BOLIVARIANO', 'EXPRESO', 'TOUR',
    'VIAJES', 'RESORT', 'FINCA', 'GLAMPING', 'SATENA', 'CLIC AIR',
  ]),
  KeywordRule(_entretenimiento, [
    'CINE COLOMBIA', 'CINECOLOMBIA', 'CINEMARK', 'PROCINAL', 'ROYAL FILMS',
    'CINEPOLIS', 'STEAM', 'PLAYSTATION', 'XBOX', 'EPIC GAMES', 'RIOT',
    'NINTENDO ESHOP', 'SMART FIT', 'SMARTFIT', 'BODYTECH', 'GYM', 'GIMNASIO',
    'TUBOLETA', 'TU BOLETA', 'TICKETMASTER', 'EVENTO', 'TEATRO', 'BOLOS',
    'CASINO', 'DISCOTECA', 'LICORERA', 'LICORES', 'BAR ', 'CERVECERIA',
    'KARAOKE', 'BILLAR', 'PARQUE', 'SALITRE MAGICO', 'MUNDO AVENTURA',
    'CONCIERTO', 'FESTIVAL', 'MUSEO', 'SPA', 'BARBERIA', 'PELUQUERIA',
    'ESTETICA', 'ROBLOX', 'GARENA', 'FREE FIRE', 'FORTNITE',
  ]),
];

const _mercado = 'mercado';
const _restaurantes = 'restaurantes';
const _transporte = 'transporte';
const _hogar = 'hogar';
const _suscripciones = 'suscripciones';
const _salud = 'salud';
const _compras = 'compras';
const _educacion = 'educacion';
const _viajes = 'viajes';
const _entretenimiento = 'entretenimiento';

/// Comprobación en tiempo de ejecución de que todas las reglas apuntan a
/// categorías existentes (útil en tests).
bool keywordRulesAreConsistent(List<KeywordRule> rules) {
  final ids = Categories.all.map((c) => c.id).toSet();
  return rules.every((r) => ids.contains(r.categoryId));
}
