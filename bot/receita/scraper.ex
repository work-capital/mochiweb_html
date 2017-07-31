defmodule Company.Bot.Info.Scraper do
  @moduledoc """
  A CNPJ scraper.
  This module define a functions to consult for CNPJ in the gov NFe portal http://www.receita.fazenda.gov.br/PessoaJuridica/CNPJ/cnpjreva/Cnpjreva_Solicitacao2.asp
  taking as a parameter a CNPJ represented as String
  This module is a replacement for the current used http://receitaws.com.br

  how it's work?\n
  -> perform a http request to receita portal,\n
  -> save response cookie from headers to keep the same session in next requests\n
  -> read response body, and solve captcha\n
  -> generate body with captcha result and cnpj access key,\n
  -> http post with this body and with the cookie above\n
  """

  # Comment one of the following lines for slecting between two captcha engines
  # TODO: Refactor the captcha file to be able to select different captcha service
  # provider by configuration and not by ugly commenting technique
  alias DeathByCaptcha.Captcha
  # alias Helpers.Gcloud.Storage
  alias GCloudex.CloudStorage.Client, as: CloudStorage
  alias UtilsBank.Result
  require Logger
  import PlumberGirl #, only: [tee: 2,try_catch: 2, >>>: 2]

  @base_url                 "http://www.receita.fazenda.gov.br/PessoaJuridica/CNPJ/cnpjreva/"
  @init_url                 "http://www.receita.fazenda.gov.br/PessoaJuridica/CNPJ/cnpjreva/Cnpjreva_Solicitacao2.asp"
  @post_url                 "http://www.receita.fazenda.gov.br/PessoaJuridica/cnpj/cnpjreva/valida.asp"
  @partners_url             "http://www.receita.fazenda.gov.br/PessoaJuridica/cnpj/cnpjreva/Cnpjreva_qsa.asp"
  @captcha_url              "http://www.receita.fazenda.gov.br/PessoaJuridica/cnpj/cnpjreva/captcha/gerarCaptcha.asp"
  @bucket_cnpj_html         "workcapital-cnpj-html"
  @bucket_partners_html     "workcapital-cnpj-partners-html"
  @bucket                   "work-capital-cnpj-receita-json"
  @sourceId                 "c683189c-796f-4c5a-b9c2-bebe004c8750"
  @cnpj_format_characters   [".", "/", "-"]
  @data_type                :json
  @timeout_opts             [{:timeout, 20_000}, {:recv_timeout, 20_000}]

  defp post(url, body, headers \\ [], options \\ []), do: HTTPoison.post(url, body, headers, options)
  defp get(url, headers \\ []), do: HTTPoison.get(url, headers)

  def job_status, do: %{idle:      :idle,
                        searching: :searching,
                        found:     :found,
                        not_found: :not_found}

  @fields %{
        cnpj:        :cnpj,
        captcha:     :txtTexto_captcha_serpro_gov_br,
        origem:      :origem,
        image:       :imgCaptcha,
        submit1:     :submit1,
        search_type: :search_type }

  @form_data_structure [{:cnpj, ""},
        {:txtTexto_captcha_serpro_gov_br, ""},
        {:origem,      "comprovante"},
        {:submit1,     "Consultar"},
        {:search_type, "cnpj"}]

      @doc ~S"""
      checks if file exists in storage
      if exsits-> returns the json file
      if does not exist-> runs update_company_info
      and returns json file

      # Examples
      iex> Company.Bot.Info.Scraper.get_company_info "27865757000102"|> IO.puts
      {"partners":[{"qualification":"10-Diretor","name":"CARLOS HENRIQUE SCHRODER"},{"qualification":"10-Diretor","name":"JORGE LUIZ DE BARROS NOBREGA"},{"qualification":"10-Diretor","name
      ":"ROSSANA FONTENELE BERTO"},{"qualification":"10-Diretor","name":"ALI AHAMAD KAMEL ALI HARFOUCHE"},{"qualification":"10-Diretor","name":"WILLY HAAS FILHO"},{"qualification":"10-Dire
      tor","name":"JUAREZ DE QUEIROZ CAMPOS JUNIOR"},{"qualification":"10-Diretor","name":"SERGIO LOURENCO MARQUES"},{"qualification":"10-Diretor","name":"MARCELO LUIS MENDES SOARES DA SIL
      VA"},{"qualification":"10-Diretor","name":"ANTONIO CLAUDIO FERREIRA NETTO"},{"qualification":"10-Diretor","name":"CRISTIANE DELECRODE LOPES SUT RIBEIRO"}],"UF":"RJ","TÍTULO DO ESTABE
      LECIMENTO (NOME DE FANTASIA)":"GCP,TV GLOBO, REDE GLOBO, GLOBO.COM, SOM LIVRE","TELEFONE":["(21) 2540-2623"],"SITUAÇÃO ESPECIAL":"********","SITUAÇÃO CADASTRAL":"ATIVA","REPÚBLICA FE
      DERATIVA DO BRASIL":["CADASTRO NACIONAL DA PESSOA JURÍDICA"],"NÚMERO DE INSCRIÇÃO":["27.865.757/0001-02","MATRIZ"],"NÚMERO":"303","NOME EMPRESARIAL:":"GLOBO COMUNICACAO E PARTICIPACO
      ES S/A","NOME EMPRESARIAL":"GLOBO COMUNICACAO E PARTICIPACOES S/A","MUNICÍPIO":"RIO DE JANEIRO","MOTIVO DE SITUAÇÃO CADASTRAL":"","LOGRADOURO":"R LOPES QUINTAS","ENTE FEDERATIVO RESP
      ONSÁVEL (EFR)":["*****"],"ENDEREÇO ELETRÔNICO":"","DATA DE ABERTURA":"31/01/1986","DATA DA SITUAÇÃO ESPECIAL":"********","DATA DA SITUAÇÃO CADASTRAL":"03/11/2005","CÓDIGO E DESCRIÇÃO
       DAS ATIVIDADES ECONÔMICAS SECUNDÁRIAS":[{"text":"Reprodução de vídeo em qualquer suporte","code":"18.30-0-02"},{"text":"Portais, provedores de conteúdo e outros serviços de informaç
      ão na internet","code":"63.19-4-00"},{"text":"Agenciamento de espaços para publicidade, exceto em veículos de comunicação","code":"73.12-2-00"},{"text":"Programadoras","code":"60.22-
      5-01"}],"CÓDIGO E DESCRIÇÃO DA NATUREZA JURÍDICA":"205-4 - Sociedade Anônima Fechada","CÓDIGO E DESCRIÇÃO DA ATIVIDADE ECONÔMICA PRINCIPAL":{"text":"Atividades de televisão aberta","
      code":"60.21-7-00"},"COMPLEMENTO":"","CEP":"22.460-901","CAPITAL SOCIAL:":"R$ 6.408.935.530,37 (Seis bilhões, quatrocentos e oito milhões, novecentos e trinta e cinco mil e quinhento
      s e trinta reais e trinta e sete centavos)","BAIRRO/DISTRITO":"JARDIM BOTANICO"}

      iex> Company.Bot.Info.Scraper.get_company_info "2786575700010"
      {:error, "Invalid CNPJ"}

      iex> Company.Bot.Info.Scraper.get_company_info "17835042000307" |> IO.puts
      "{"UF":"MT","TÍTULO DO ESTABELECIMENTO (NOME DE FANTASIA)":"********","TELEFONE":"","SITUAÇÃO ESPECIAL":"********","SITUAÇÃO CADASTRAL":"ATIVA","REPÚBLICA FEDERA
      TIVA DO BRASIL":["CADASTRO NACIONAL DA PESSOA JURÍDICA"],"NÚMERO DE INSCRIÇÃO":["17.835.042/0003-07","FILIAL"],"NÚMERO":"S/N","NOME EMPRESARIAL":"ABC-INDUSTRIA E COME
      RCIO S/A-ABC-INCO","MUNICÍPIO":"ALTO ARAGUAIA","MOTIVO DE SITUAÇÃO CADASTRAL":"","LOGRADOURO":"ROD BR 364","ENTE FEDERATIVO RESPONSÁVEL (EFR)":["*****"],"ENDEREÇO E
      LETRÔNICO":"","DATA DE ABERTURA":"13/09/1994","DATA DA SITUAÇÃO ESPECIAL":"********","DATA DA SITUAÇÃO CADASTRAL":"22/10/2005","CÓDIGO E DESCRIÇÃO DAS ATIVIDADES ECON
      ÔMICAS SECUNDÁRIAS":[{"text":"Comércio atacadista de soja","code":"46.22-2-00"},{"text":"Atividades de pós-colheita","code":"01.63-6-00"},{"text":"Depósitos de me
      rcadorias para terceiros, exceto armazéns gerais e guarda-móveis","code":"52.11-7-99"}],"CÓDIGO E DESCRIÇÃO DA NATUREZA JURÍDICA":"205-4 - SOCIEDADE ANONIMA FECHADA","CÓDIG
      O E DESCRIÇÃO DA ATIVIDADE ECONÔMICA PRINCIPAL":{"text":"Comércio atacadista de matérias-primas agrícolas não especificadas anteriormente","code":"46.23-1-99"},"COMPLEMENTO
      ":"KM 7","CEP":"78.780-000","BAIRRO/DISTRITO":"DISTR INDUSTRIAL"}"
      """

      def perform(cnpj), do: update_company_info(cnpj)

      def get_company_info(cnpj) do
        if company_info_exists_in_storage?(cnpj) do
          {:ok, info} = get_company_info_from_storage(cnpj)
          Company.Map.parse(info.body)
        else
          update_company_info(cnpj)
        end
      end

      defp get_update_result(cnpj) do
        case update_company_info(cnpj) do
          {:error,"invalid CNPJ"}                       ->  Logger.error("Invalid CNPJ: #{cnpj}")
                                                            {:error,"Invalid CNPJ"}
          {:error,"captcha was not solved correctly"}   ->  Logger.error("Wrong captcha result")
                                                            get_update_result(cnpj)
          {:ok, result}                                 ->  {:ok, result}
          {:error, message}                             ->  {:error, message}
          result                                        ->  {:ok, result}
        end
      end

      def company_info_exists_in_storage?(cnpj) do
        {:ok, %HTTPoison.Response{body: body}} = CloudStorage.list_objects(@bucket)
        body =~ "#{cnpj}.#{@data_type}"
      end

      defp get_company_info_from_storage(cnpj) do
        Logger.info "getting company: #{cnpj} json files from storage"
        {:ok, info} = CloudStorage.get_object(@bucket, "#{cnpj}.#{@data_type}")
      end

      def update_company_info(company_cnpj) do
        Logger.info "updating company: #{company_cnpj} info..."
        cnpj = remove_format_characters(company_cnpj)

        result =
          %Cnpj{number: cnpj}
          |>       Brcpfcnpj.cnpj_valid?
          |>       start_session
          >>>      get_htmls_bodies(cnpj)   #returns both global and partners htmls bodies
          >>> (tee store_htmls(cnpj))
          >>>      parse_html(cnpj)         #returns a json of the whole html(including partners details)
          >>> (tee storage_upload("#{cnpj}.#{@data_type}", @bucket, @data_type))
          >>>      Company.Map.parse()
      end

      defp start_session (true) do
        Logger.info "Starting session"
        get(@init_url)
        >>>  process_response(200)
      end

      defp process_response(response, expected_code) do
        %{response: method_response, captcha_id: captcha_id} =
          case response do
            %{response: method_response, captcha_id: captcha_id} -> %{response: method_response, captcha_id: captcha_id}
            response                                             -> %{response: response, captcha_id:  "0"}
          end
          Logger.info "process response: #{inspect method_response.status_code} statusCode: #{inspect expected_code}"
          case method_response.status_code == expected_code do
            true  -> Result.return %{cookies:      find_cookies(method_response),
                                     responseBody: method_response.body}
            false -> Result.fail   %{message: "status code error. \n response.status_code: " <>
                                     to_string(method_response.status_code)  <>
                                     " doesn't match to" <> to_string(expected_code),
                                     details: %{status_code: method_response.status_code,
                                     response: method_response,
                                     captcha_id:   captcha_id}}
          end
        end

      defp find_cookies(response) do
        headers = Enum.into(response.headers, %{})
        cookies = headers["Set-Cookie"]
        cookies
      end

      defp get_htmls_bodies(%{cookies: cookies, responseBody: responseBody}, cnpj) do
        headers = generate_headers(%{cookies: cookies})
        {:ok, %{:body => captcha_img}}   = get(@captcha_url, headers)

        Logger.info "got captcha image"
        {:ok, {captcha_txt, captcha_id}} = Captcha.processBase64Data(Base.encode64(captcha_img))

        Logger.info "Solved Captcha #{captcha_txt}"
        form_data =    @form_data_structure
                    |> Keyword.put(@fields.cnpj,    cnpj)
                    |> Keyword.put(@fields.captcha, captcha_txt)

        Logger.info "formData =  #{inspect form_data}"
        {:ok, res} = post(@post_url, {:form, form_data}, headers, [])
        {"Location", next_location} = List.keyfind(res.headers, "Location", 0)
        {:ok, res} = get(@base_url <> next_location, headers)

        case List.keyfind(res.headers, "Location", 0)  do

          {"Location", next_location} ->  {:ok, res} = get(@base_url  <> next_location, headers)
                                          {"Location", next_location} = List.keyfind(res.headers, "Location", 0)
                                          {:ok, res_global}   = get(@base_url <> next_location, headers)
                                          {:ok, res_partners} = get(@partners_url, headers)
                                          if company_has_partners?(res_partners.body) do
                                              Result.return ({res_global.body, res_partners.body})
                                            else
                                              Result.return ({res_global.body, nil})
                                          end
          _result                     -> Result.fail "captcha was not solved correctly"
        end
      end

      def remove_format_characters(cnpj) do
        Enum.reduce(@cnpj_format_characters, cnpj, &(String.replace(&2, &1, "")))
      end

      defp generate_headers(%{cookies: cookies}) do
        [{"Cookie", cookies}]
      end

      defp store_htmls({global_html, partners_html}, cnpj) do
        file_name = "#{cnpj}.html"
        storage_upload(global_html, file_name, @bucket_cnpj_html, :html)
        storage_upload(partners_html, file_name, @bucket_partners_html, :html)
      end

      defp parse_html({global_html, partners_html}, cnpj) do
        Logger.info("Parsing company: #{cnpj} HTML info to JSON")
        {global_html, partners_html}
        |> (Bot.CompanyInfo.Parser.Global.parse)
      end

      defp company_has_partners?(partners_html) do
        if String.contains?(partners_html, "Object Moved"), do: false, else: true
      end

      def storage_upload(data, file_name, bucket_name, :pdf) do
        CloudStorage.put_object_content(bucket_name, file_name, "application/pdf", data)
      end

      def storage_upload(data, file_name, bucket_name, :html) do
        CloudStorage.put_object_content(bucket_name, file_name, "text/html", data)
      end

      def storage_upload(data, file_name, bucket_name, :json) do
          CloudStorage.put_object_content(bucket_name, file_name, "application/json", data)
      end
end
