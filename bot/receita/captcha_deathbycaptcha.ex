defmodule DeathByCaptcha.Captcha do

 import PlumberGirl
 
 @username "kalmus"
 @password "{gpg]wF|4eDF~7Rr5}#LXzx!ykFx2NYMug"
 @timeout_opts [{:timeout, 20000}, {:recv_timeout, 20000}]

 @doc ~S"""

       ## Examples
            iex> {:ok, data} = File.read "lib/NFe/doc/base64img_w68hp_with_prefix"
            iex> NFe.Captcha.processBase64Data(data)
            iex> {:ok, data} = File.read "lib/NFe/doc/base64img_eke5c5"
            iex> NFe.Captcha.processBase64Data(data)
    """

  def processBase64Data(base64data) do
      case String.split(base64data, ",") do
        [_, base64img] -> upload(base64img)
        [base64img]    -> upload(base64img)
      end
  end

  def upload(body) do
      form = {:multipart, [{"username", @username},
                          {"password", @password},
                          {"captchafile", "base64:" <> body}]}
          HTTPoison.post("http://api.dbcapi.me/api/captcha", form, [], @timeout_opts)
      >>> processResponse()
      >>> get_res()
  end

  def processResponse(response) do
     case response.status_code  do
        303 -> {:ok, URI.decode_query(response.body)["captcha"]}
        403 -> {:error, "DeathByCaptcha Error: Forbidden"}
        400 -> {:error, "DeathByCaptcha Error: Bad Request"}
        500 -> {:error, "DeathByCaptcha Error: Internal Server Error"}
        503 -> {:error, "DeathByCaptcha Error: Service Temporarily Unavailable"}
     end
  end

  def get_res(id) do
        HTTPoison.get("http://api.dbcapi.me/api/captcha/" <> id, [], @timeout_opts)
    >>> processResult()
    >>> case  do
         :captcha_not_ready -> :timer.sleep(3000)
                                get_res(id)
          captcha   -> {:ok, {captcha, id}}
        end
  end

  def processResult(response) do
      case response.status_code do
        404 -> {:error, "Not Found"}
        200 -> case URI.decode_query(response.body)["text"] do
                  ""      -> {:ok, :captcha_not_ready}
                  captcha -> {:ok, captcha}
               end
      end
  end

  # def report_wrong_captcha(id, 3), do:
  def report_wrong_captcha(id) do
    form = {:multipart, [{"username", @username},
                        {"password", @password}]}
    {:ok, _response} = HTTPoison.post("http://api.dbcapi.me/api/captcha/" <> id <> "/report", form, [], @timeout_opts)
    # case response.status_code do
    #   200 -> response
    #   _   -> report_wrong_captcha(id, retries + 1)
    # end
  end

end
