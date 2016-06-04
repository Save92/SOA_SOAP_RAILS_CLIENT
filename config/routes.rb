Rails.application.routes.draw do

  #post 'soap_call/:login/:password', to: 'soap_weather#soap_call'
  wash_out :soap_weather

end
