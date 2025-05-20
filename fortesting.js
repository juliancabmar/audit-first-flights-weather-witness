#!/usr/bin/env node

// filepath: /home/lubuntu/Desktop/Projects/Crypto/Audit competitions/First_Flights/audit-first-flights-weather-witness/fortesting.js

// Importa las dependencias necesarias
const axios = require('axios');

// Asegúrate de que los argumentos sean proporcionados
const args = process.argv.slice(2);
if (args.length < 2) {
  console.error("Usage: node fortesting.js <zip_code> <country_code>");
  console.log("Example: node fortesting.js 94040 US");  
  process.exit(1);
}

// Define tu clave API (asegúrate de configurarla correctamente)
const secrets = {
  apiKey: "bca9fc3cd9e2963cd40063d4db8f7a16" // Reemplaza con tu clave API de OpenWeather
};

// Función principal
(async () => {
  try {
    // ref: https://openweathermap.org/api/geocoding-api
    const geoCodingRequest = await axios.get("http://api.openweathermap.org/geo/1.0/zip", {
      params: { zip: `${args[0]},${args[1]}`, appid: secrets.apiKey }
    });

    const geoCodingResponse = geoCodingRequest.data;

    if (!geoCodingResponse.lat || !geoCodingResponse.lon) {
      throw new Error("Invalid geocoding response. Check the provided parameters.");
    }

    // ref: https://openweathermap.org/current
    const weatherRequest = await axios.get("https://api.openweathermap.org/data/2.5/weather", {
      params: { lat: geoCodingResponse.lat, lon: geoCodingResponse.lon, appid: secrets.apiKey }
    });

    const weatherResponse = weatherRequest.data;

    if (!weatherResponse.weather || weatherResponse.weather.length === 0) {
      throw new Error("Invalid weather response. Check the provided parameters.");
    }

    const weather_id = weatherResponse.weather[0].id;
    const weather_id_x = parseInt(weather_id / 100);

    let weather_enum = 0;

    // ref: https://openweathermap.org/weather-conditions
    // thunderstorm
    if (weather_id_x === 2) weather_enum = 3;
    // rain
    else if (weather_id_x === 3 || weather_id_x === 5) weather_enum = 2;
    // snow
    else if (weather_id_x === 6) weather_enum = 5;
    // clear
    else if (weather_id === 800) weather_enum = 0;
    // cloudy
    else if (weather_id_x === 8) weather_enum = 1;
    // windy
    else weather_enum = 4;

    console.log(`Weather Enum: ${weather_enum}`);
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
})();