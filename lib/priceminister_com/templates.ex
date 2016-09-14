defmodule PriceministerCom.Templates do
  @moduledoc false

  require DateTime
  require HTTPoison
  require Kernel
  require PriceministerCom
  require SweetXml

  def query(channel, alias) do
    method = :get
    url = PriceministerCom.get_url(channel["url"], "/stock_ws")
    body = ""
    headers = []
    params = %{
      "action" => "producttypetemplate",
      "alias" => alias,
      "login" => channel["login"],
      "pwd" => channel["pwd"],
      "scope" => "VALUES",
      "version" => "2015-02-02",
    }
    options = [
      {:params, params}
    ]
    response = parse_http(HTTPoison.request(method, url, body, headers, options))
    response
  end

  def parse_http({:ok, %HTTPoison.Response{status_code: 200, body: body}}) do
    template = parse_xml(body)
    {:ok, template}
  end

  def parse_http({:ok, %HTTPoison.Response{status_code: status_code}}) do
    {:error, status_code}
  end

  def parse_http({:error, %HTTPoison.Error{reason: reason}}) do
    {:error, reason}
  end

  def parse_xml(body) do
    response = SweetXml.xpath(body, SweetXml.sigil_x("//response", 'e'))
    name = ""
    name_fr = SweetXml.xpath(response, SweetXml.sigil_x("./prdtypelabel/text()", 's'))
    sections = get_sections(response)
    %{
      "name" => name,
      "name_fr" => name_fr,
      "sections" => sections,
    }
  end

  def get_sections(response) do
    advert = get_section(response, "advert")
    media = get_section(response, "media")
    product = get_section(response, "product")
    %{
      "advert" => advert,
      "media" => media,
      "product" => product,
    }
  end

  def get_section(response, section) do
    section = SweetXml.xpath(response, SweetXml.sigil_x("./attributes/#{section}", 'e'))
    attributes = SweetXml.xpath(section, SweetXml.sigil_x("./attribute", 'el'))
    attributes = Enum.reduce(
      attributes,
      %{},
      fn(attribute, attributes) ->
        attribute = get_attribute(attribute)
        Map.merge(attributes, attribute)
      end
    )
    attributes
  end

  def get_attribute(attribute) do
    key = SweetXml.xpath(attribute, SweetXml.sigil_x("./key/text()", 's'))
    name = ""
    name_fr = SweetXml.xpath(attribute, SweetXml.sigil_x("./label/text()", 's'))
    is_mandatory = SweetXml.xpath(attribute, SweetXml.sigil_x("./mandatory/text()", 's'))
    is_mandatory = get_is_mandatory(is_mandatory)
    options = SweetXml.xpath(attribute, SweetXml.sigil_x("./valueslist/value/text()", 'sl'))
    options = get_options(options)
    type = SweetXml.xpath(attribute, SweetXml.sigil_x("./valuetype/text()", 's'))
    type = get_type(options, type)
    value = %{
      "name" => name,
      "name_fr" => name_fr,
      "is_mandatory" => is_mandatory,
      "type" => type,
      "options" => options,
    }
    %{
      key => value
    }
  end

  def get_is_mandatory("0") do
    false
  end

  def get_is_mandatory("1") do
    true
  end

  def get_is_mandatory(_) do
    false
  end

  def get_options(options) do
    options = Enum.map(options, fn(option) -> String.trim(option) end)
    options = Enum.filter(options, fn(option) -> String.length(option) > 0 end)
    options = Enum.reduce(options, %{}, fn(option, options) -> Map.put(options, option, "") end)
    options
  end

  def get_type(options, "Boolean") when Kernel.map_size(options) == 0 do
    ~s(input[type="checkbox"])
  end

  def get_type(options, "Date") when Kernel.map_size(options) == 0 do
    ~s(input[type="date"])
  end

  def get_type(options, "Number") when Kernel.map_size(options) == 0 do
    ~s(input[type="number"])
  end

  def get_type(options, "Text") when Kernel.map_size(options) == 0 do
    ~s(input[type="text"])
  end

  def get_type(options, _type) when Kernel.map_size(options) == 0 do
    ~s(input[type="text"])
  end

  def get_type(options, _type) when Kernel.map_size(options) != 0 do
    "select"
  end
end
