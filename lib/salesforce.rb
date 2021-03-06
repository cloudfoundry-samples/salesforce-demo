SALESFORCE_OPTIONS = {:mode => :header, :header_format => 'OAuth %s'}

def salesforce_callback
  "#{SalesforceDemo::Config.host}/oauth/callback"
end

def get_access_token code
  resp = client.auth_code.get_token(code, :redirect_uri => salesforce_callback, :grant_type => 'authorization_code')
  session['salesforce_access_token'] = resp.token
  x = resp.instance_url
  if (x)
    x.gsub!('https://', '')
    x.gsub!('.salesforce.com', '')
  end
  session['salesforce_instance_url'] = x
end

def access_token
  if (session.has_key? 'salesforce_access_token')
    return OAuth2::AccessToken.new(client, session['salesforce_access_token'], SALESFORCE_OPTIONS.clone)
  else
    session['url'] = request.path
    redirect client.auth_code.authorize_url(
      :response_type => 'code',
      :redirect_uri => salesforce_callback
    )
  end
end

def instance
  session['salesforce_instance_url'] || ENV['salesforce_instance_url']
end

def instance_url
  "https://#{instance}.salesforce.com"
end

def client
  OAuth2::Client.new(
    ENV['salesforce_key'],
    ENV['salesforce_secret'],
    :site => instance_url,
    :authorize_url =>'/services/oauth2/authorize?immediate=false',
    :token_url => '/services/oauth2/token',
    :ssl=>{
    :verify=>false
    }
  )
end

def show_all object_type, options={}
  url = "#{instance_url}/services/data/v20.0/query/?q=#{CGI::escape("SELECT Name, Id from #{object_type.capitalize} LIMIT 100")}"
  output = nil
  begin
    response = access_token.get(url, :headers => {'Content-type' => 'application/json'})

     if (options[:raw] == true)
      return response.body
     elsif (response.parsed['records'].count > 0)
      return response.parsed['records']
     end
  rescue OAuth2::Error => e
    SalesforceDemo::Config.logger.error("Error getting #{object_type}s #{e.response.inspect}")
  end
  output
end

def create object_type, json
  begin
    response = access_token.post("#{instance_url}/services/data/v20.0/sobjects/#{object_type.capitalize}/", :body =>json, :headers => {'Content-type' => 'application/json'}).parsed
    return response['id']
  rescue OAuth2::Error => e
    return e.response.inspect
  end
end

def show_one object_type, id, options={}
  begin
    response = access_token.get("#{instance_url}/services/data/v20.0/sobjects/#{object_type.capitalize}/#{id}", :headers => {'Content-type' => 'application/json'})

    if (options[:raw] == true)
      return response.body
    else
      return response.parsed
    end
  rescue OAuth2::Error => e
     return e.response.inspect
  end
end

def update object_type, id, json

  begin
    access_token.post("#{instance_url}/services/data/v20.0/sobjects/#{object_type.capitalize}/#{id}?_HttpMethod=PATCH", :body => json, :headers => {'Content-type' => 'application/json'})
  rescue OAuth2::Error => e
      e.response.inspect
  end
end

def delete object_type, id
  begin
    access_token.delete("#{instance_url}/services/data/v20.0/sobjects/#{object_type}/#{id}")
  rescue OAuth2::Error => e
      e.response.inspect
  end
end
