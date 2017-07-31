defmodule Bot.CompanyInfo.Parser.Global do
  @doc ~S"""
   Description
    a parser for company info
    output : A json with the company details
  ## Examples
  """
  def parse({global_html, partners_html}) do
      if (:erlang.is_binary(global_html)) do
          html =  global_html
          |> :erlang.binary_to_list
          |> to_string
      else
      {:error, "wrong format"}
      end
      myjson = Map.new;
      tables = Floki.find(html, "table")
      result = get_table_details(tables, myjson)
      |> Poison.encode!
      if partners_html do
        {:ok, Bot.CompanyInfo.Parser.Partners.parse(partners_html|> :erlang.binary_to_list |> to_string, result)}
      else
        {:ok, result}
      end
    end

  defp get_table_details([head | tail], myjson) do
      tds = Floki.find(head, "td")
      res = get_tds_details(tds, myjson)
      get_table_details(tail, res)
  end

  defp get_table_details([], myjson) do
      myjson
  end

  defp get_tds_details([head | tail],myjson) do
    text = Floki.text(head)
    substring = String.split(text, "\n")

    if key_has_value(substring) do
      key = get_key(substring)
      value = get_value(substring)
      myjson = add_to_json(myjson,key,value)
    end
    get_tds_details(tail,myjson)
  end

  defp get_tds_details([], myjson) do
    myjson
 end

  defp key_has_value(substring) do
    if Enum.at(substring,3) != nil do
      true
    else
      false
    end
  end

  defp get_key(substring) do
    Enum.at(substring,1,"")|>String.split("\n")|> Enum.at(0, "")|>String.trim
  end

  defp get_value(substring) do
    if has_multiple_details(substring)  do
      value=create_list_of_details(substring)
      if Enum.all?(value, fn arg ->is_text_code_obj(arg)  end) do
        value=Enum.to_list(value)
        value=create_text_and_code_json(value,[])
      end
    else
      value=get_single_value(substring)
        if is_text_code_obj(value) do
          value=create_text_and_code_json(value)
        end
    end
    value
  end

  defp has_multiple_details(substring) do
    if Enum.at(substring,4)!="" do
      true
    else
      false
    end
  end

  defp create_list_of_details(substring) do
    Enum.drop(substring, 3)
    |> Enum.map(fn arg -> String.trim(arg) end)
    |> Enum.filter(fn arg -> arg != ""  end)
  end

  defp is_text_code_obj(value) do
    regex = ~r/\d{2}\.\d{2}\-\d{1}\-\d{2}\ -  *\w/
    if Regex.match?(regex, value) do
      true
    else
      false
    end
  end

  defp get_single_value(substring) do
    Enum.at(substring, 3) |> String.trim
  end

  defp add_to_json(myjson, key, value) do
    Map.put(myjson, key, value)
  end

  defp create_text_and_code_json([head | tail], list) do
    list = list ++ [create_text_and_code_json(head)]
    create_text_and_code_json(tail,list)
  end

  defp create_text_and_code_json([],list) do
    list
  end

  defp create_text_and_code_json(value) do
    tmpJson = Map.new
    split = String.split(value, " - ")
    code = Enum.at(split, 0)
    text = Enum.at(split, 1)|>String.trim
    tmpJson = Map.put(tmpJson, "code", code)
    tmpJson = Map.put(tmpJson, "text", text)
    tmpJson
  end

end
