defmodule Bot.CompanyInfo.Parser.Partners do
  use PlumberGirl
  @doc ~S"""
   Description
   input:html- a html's page with a companys partners details
         json- a Map
   The function parses the html in to json and adds it to the "main json" received.

  ## Examples
  iex> {:ok,data}= File.read("./test/company-info/src/comapny_partners_html.txt")
  ...> result=(Cnpj.Parser.Partners.parse(data, Map.new))
  ...> Poison.decode!(result)
  %{"CAPITAL SOCIAL:" => "R$ 90.000,00 (Noventa mil reais)",
  "NOME EMPRESARIAL:" => "WORKCAPITAL BSD FOMENTO MERCANTIL EIRELI",
  "partners" => [%{"name" => "SIMAO HAMERMESZ NEUMARK",
  "qualification" => "65-Titular Pessoa Física Residente ou Domiciliado no Brasil"}]}
  """
  def parse(html, json) do
    json = Poison.decode!(json)                                    #parse json to map
    company_details = get_details_table(html)                      #get the table in html that contains companys datails
    json = Map.merge(json, get_company_json(company_details, json)) #add companys details to main map
    partners_html = Floki.find(html, "fieldset")                     #gets list of partners html
    partners = get_partners_json(partners_html, [])
       Map.put(json, "partners", partners)                      #add partners json to main json
    |> remove_duplicates()
    |> Poison.encode!()#parse map tp json
  end

  defp get_details_table(html) do
    Floki.find(html, "table") #get all tables
    |> Enum.find(fn(table) -> String.contains?(Floki.text(table), "NOME EMPRESARIAL:") end)#get table that contains "NOME EMPRESARIAL"
  end

  defp get_company_json(html, json) do
      res = Floki.text(html, sep: "$$")
      |> String.split("$$")
      json = add_to_json(res, json)
  end

#recursivly add all details in list to json
  defp add_to_json([head | tail], json) do
    key = head
    value = List.first(tail)
    json = Map.put(json, key, value)
    add_to_json(tail--[value], json)
  end
  defp add_to_json([], json) do
    json
  end

  defp get_partners_json([head | tail], result) do
    result = result++ [create_partner_json(head)]
    get_partners_json(tail, result)
  end

  defp get_partners_json([], result) do
    result
  end

  defp create_partner_json(partner) do
    partner_json = Map.new
    partners_text = Floki.find(partner, "[width=300px]")
    |> Floki.raw_html
    |> Floki.text
    |> String.split "                                                                                         "

    partners_text = Enum.map(partners_text, fn(x) -> String.trim(x) end)#trim whitespaces
    name = Enum.at(partners_text, 0)
    qualification = Enum.at(partners_text, 1)

    partner_json = Map.put(partner_json, "name", name)
    partner_json = Map.put(partner_json, "qualification", qualification)
  end

  defp remove_duplicates(map) do
  map = Map.delete(map, "NOME EMPRESARIAL:")
  map = Map.delete(map, "CNPJ:")
  end
end
