require 'bundler'
Bundler.require

require 'json'

configure do
  set :jekyll_site_path, 'shineyoureye'
  set :pu_lookup_api_url, 'https://pu-lookup.herokuapp.com'
  jekyll_site.config['url'] ||= 'http://staging.shineyoureye.org'
  # Run generators for Jekyll
  jekyll_site.generate
end

helpers do
  def pu_lookup(pun)
    response = RestClient.get(
      settings.pu_lookup_api_url,
      params: { lookup: pun }
    )
    JSON.parse(response, symbolize_names: true)
  rescue RestClient::ResourceNotFound => e
    logger.warn(e.message)
    nil
  end
end

get '/' do
  if params[:q]
    @result = pu_lookup(params[:q])
    @area = @result[:area]
    @state = @result[:states].first
    @governor = jekyll_site.collections['executive_governors'].docs.find_all do |d|
      d['area'] == @state[:name]
    end.reject do |d|
      d['end_date'] && Date.parse(d['end_date']) < Date.today
    end.first
    assembly_fuzzer = FuzzyMatch.new(jekyll_site.collections['assembly_areas'].docs, read: 'name')
    @federal_constituencies = @result[:federal_constituencies].map do |fc|
      assembly_fuzzer.find(fc[:name])
    end.compact
    senate_fuzzer = FuzzyMatch.new(jekyll_site.collections['senate_areas'].docs, read: 'name')
    @senatorial_districts = @result[:senatorial_districts].map do |sd|
      senate_fuzzer.find(sd[:name])
    end.compact
  end
  render_into_jekyll_layout erb(:index), 'disable_breadcrumbs' => true
end
