require 'uri'
require 'net/http'
require 'savon'
require 'xmlrpc/client'


class SoapWeatherController < ApplicationController
  soap_service namespace: 'urn:WashOut'

  soap_action 'soap_call', args: { login: :string, password: :string, lat: :double, lon: :double, authent_ip: :string, authent_method: :string }, return: :string
  def soap_call
    ap params
    # on recupere les parametres pour l'authent
    authent_params = { 'login' => params[:login], 'password' => params[:password] }
    #on construit l'appel au bon serveur d'authent
    #ap "http://#{params[:authent_ip]}/#{params[:authent_method]}"
    response = Net::HTTP.post_form(URI.parse("http://#{params[:authent_ip]}/#{params[:authent_method]}"), authent_params)
    #on recupere le token
    token = JSON.parse(response.body)["token"]
    # si le token existe
    if token
        # on créé notre connexion au rpc
        rpc_client = XMLRPC::Client.new 'localhost', '/', 1234
        # on appel notre rpc
        ap params[:lat]
        ap params[:lon]
        geo_info = rpc_client.call('my_rpc.lat_lon_info', params[:lat], params[:lon])
        #on récupère les infos
        geo_info = JSON.parse geo_info
        ap geo_info
        # on créé notre connexion au SOAP client
        soap_client = Savon.client do
          wsdl 'http://www.webservicex.net/globalweather.asmx?WSDL'
          convert_request_keys_to :camelcase
    end
    # on appel notre notre soap client avec les paramaettres récupérer via le RPC
    response = soap_client.call(:get_weather, message: { 'CityName': geo_info['city'], 'CountryName': geo_info['country'] })
    #on parse la réponse
    response_string = response.body
    response_string = response_string[:get_weather_response][:get_weather_result]
    response_string = response_string.to_s.gsub(/\n/, "")
    response_string = response_string.to_s.gsub("<?xml version=\"1.0\" encoding=\"utf-16\"?>", "")

    response_hash = Hash.from_xml(response_string)
    #on appel le rpc pour avoir le CO2
    co2 = rpc_client.call('my_rpc.co2', params[:lat].to_s[0..3], params[:lon].to_s[0..3])
    # # ap co2
    #on appel le rpc pour avoir les uv
    uv = rpc_client.call('my_rpc.uv', params[:lat].to_s[0..2], params[:lon].to_s[0..2])
    # # ap uv
    #on les ajoutes
    if co2
      response_hash['CurrentWeather']['CO2'] = co2
    end

    if uv
      response_hash['CurrentWeather']['UV'] = uv
    end

    ap response_hash
    #on retourne les infos
    render soap: response_hash.to_xml
    #message d'erreur si pas de token
    else
      render soap: 'Authentication failed. Wrong password.'
    end
  end
end
