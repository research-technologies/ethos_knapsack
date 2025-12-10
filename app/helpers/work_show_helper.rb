module WorkShowHelper

  def render_isni_or_orcid_url(id, type)
    id = id.strip.chomp('/').split('/').last
    new_id = id.delete('\n').delete('\t').gsub(/[^a-z0-9X]/, '')
    uri = URI.parse(new_id)
    if (uri.scheme.present? &&  uri.host.present?)
      domain = uri
      domain.to_s
    elsif (uri.scheme.present? == false && uri.path.present?)
      split_path(uri, type)
    elsif (uri.scheme.present? == false && uri.host.present? == false)
      create_isni_and_orcid_url(new_id, type)
    end
  end

  #The uri looks like  `#<URI::Generic orcid.org/0000-0002-1825-0097>` hence the need to split_path;
  # `split_domain_from_path` returns `["orcid.org", "0000-0002-1825-0097"]`
  # get_type is subsctracting a sub array from the main array eg (["orcid", "org"] - ["org"]) and returns ["orcid"]
  def split_path(uri, type)
    split_domain_from_path = uri.path.split('/')
    if split_domain_from_path.length == 1
      id = split_domain_from_path.join('')
      create_isni_and_orcid_url(id, type)
    else
      get_host = split_domain_from_path.shift
      split_host = get_host.split('.')
      get_type = (split_host - ['org']).join('')
      get_id = split_domain_from_path.join('')
      create_isni_and_orcid_url(get_id, get_type)
    end
  end

  def create_isni_and_orcid_url(id, type)
    if type == 'orcid'
      host = URI('https://orcid.org/')
      host.path = "/#{id}"
      host.to_s
    elsif type == "isni"
      host = URI('http://www.isni.org')
      host.path = "/isni/#{id}"
      host.to_s
    end
  end

end
