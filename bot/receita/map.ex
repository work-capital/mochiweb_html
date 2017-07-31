defmodule Company.Map do
  @moduledoc false

  def parse([%{"qualification" => qual, "name" => name} | _] = partners) do
    for %{"qualification" => qual, "name" => name} <- partners, do: %{qual: qual, nome: name}
  end

  def parse(company_info) do
    info = company_info |> Poison.decode!

    %Model.ReceitaResponse{
      status:                 "OK",
      message:                nil,
      cnpj:                   info["NÚMERO DE INSCRIÇÃO"] |> List.first,
      tipo:                   info["NÚMERO DE INSCRIÇÃO"] |> List.last,
      abertura:               info["DATA DE ABERTURA"],
      nome:                   info["NOME EMPRESARIAL"],
      fantasia:               info["TÍTULO DO ESTABELECIMENTO (NOME DE FANTASIA)"],
      atividade_principal:    info["CÓDIGO E DESCRIÇÃO DA ATIVIDADE ECONÔMICA PRINCIPAL"] |> List.wrap,
      atividades_secundarias: info["CÓDIGO E DESCRIÇÃO DAS ATIVIDADES ECONÔMICAS SECUNDÁRIAS"] |> List.wrap,
      natureza_juridica:      info["CÓDIGO E DESCRIÇÃO DA NATUREZA JURÍDICA"],
      logradouro:             info["LOGRADOURO"],
      numero:                 info["NÚMERO"],
      complemento:            info["COMPLEMENTO"],
      cep:                    info["CEP"],
      bairro:                 info["BAIRRO/DISTRITO"],
      municipio:              info["MUNICÍPIO"],
      uf:                     info["UF"],
      email:                  info["ENDEREÇO ELETRÔNICO"],
      telefone:               info["TELEFONE"] |> List.wrap |> List.first,
      efr:                    info["ENTE FEDERATIVO RESPONSÁVEL (EFR)"] |> List.first,
      situacao:               info["SITUAÇÃO CADASTRAL"],
      data_situacao:          info["DATA DA SITUAÇÃO CADASTRAL"],
      motivo_situacao:        info["MOTIVO DE SITUAÇÃO CADASTRAL"],
      situacao_especial:      info["SITUAÇÃO ESPECIAL"],
      data_situacao_especial: info["DATA DA SITUAÇÃO ESPECIAL"],
      capital_social:         info["CAPITAL SOCIAL:"],
      qsa:                    info["partners"] |> parse,
      extra:                  %{}
    }
  end

end
