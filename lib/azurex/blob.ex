defmodule Azurex.Blob do
  alias Azurex.Blob.Config
  alias Azurex.Authorization.SharedKey

  @typep optional_string :: String.t() | nil

  def list_containers do
    %HTTPoison.Request{
      url: Config.api_url() <> "/?comp=list"
    }
    |> SharedKey.sign(
      storage_account_name: Config.storage_account_name(),
      storage_account_key: Config.storage_account_key()
    )
    |> HTTPoison.request()
    |> case do
      {:ok, %{body: xml, status_code: 200}} -> {:ok, xml}
      {:ok, err} -> {:error, err}
      {:error, err} -> {:error, err}
    end
  end

  @spec put_blob(String.t(), binary, String.t(), optional_string, keyword) ::
          :ok
          | {:error, HTTPoison.AsyncResponse.t() | HTTPoison.Error.t() | HTTPoison.Response.t()}
  def put_blob(name, blob, content_type, container \\ nil, opts \\ []) do
    query =
      if timeout = Keyword.get(opts, :timeout),
        do: "?" <> URI.encode_query([{"timeout", timeout}]),
        else: ""

    %HTTPoison.Request{
      method: :put,
      url: "#{Config.api_url()}/#{get_container(container)}/#{name}#{query}",
      body: blob,
      headers: [
        {"x-ms-blob-type", "BlockBlob"}
      ],
      # Blob storage only answers when the whole file has been uploaded, so recv_timeout
      # is not applicable for the put request, so we set it to infinity
      options: [recv_timeout: :infinity]
    }
    |> SharedKey.sign(
      storage_account_name: Config.storage_account_name(),
      storage_account_key: Config.storage_account_key(),
      content_type: content_type
    )
    |> HTTPoison.request()
    |> case do
      {:ok, %{status_code: 201}} -> :ok
      {:ok, err} -> {:error, err}
      {:error, err} -> {:error, err}
    end
  end

  @spec get_blob(String.t(), optional_string) ::
          {:ok, binary()}
          | {:error, HTTPoison.AsyncResponse.t() | HTTPoison.Error.t() | HTTPoison.Response.t()}
  def get_blob(name, container \\ nil) do
    %HTTPoison.Request{
      method: :get,
      url: get_blob_url(name, container)
    }
    |> SharedKey.sign(
      storage_account_name: Config.storage_account_name(),
      storage_account_key: Config.storage_account_key()
    )
    |> HTTPoison.request()
    |> case do
      {:ok, %{body: blob, status_code: 200}} -> {:ok, blob}
      {:ok, err} -> {:error, err}
      {:error, err} -> {:error, err}
    end
  end

  @spec list_blobs(optional_string) ::
          {:ok, binary()}
          | {:error, HTTPoison.AsyncResponse.t() | HTTPoison.Error.t() | HTTPoison.Response.t()}
  def list_blobs(container \\ nil, uri_parameters \\ []) do
    %HTTPoison.Request{
      url: Config.api_url() <> "/#{get_container(container)}?comp=list&restype=container" <> join_parameters(uri_parameters)
    }
    |> SharedKey.sign(
      storage_account_name: Config.storage_account_name(),
      storage_account_key: Config.storage_account_key()
    )
    |> HTTPoison.request()
    |> case do
      {:ok, %{body: xml, status_code: 200}} -> {:ok, xml}
      {:ok, err} -> {:error, err}
      {:error, err} -> {:error, err}
    end
  end

  defp join_parameters([]) do
    ""
  end

  defp join_parameters(parameters) do
    Enum.map(parameters, fn {name, value} -> "&" <> name <> "=" <> value end)
    |> Enum.join("")
  end

  @spec get_blob_url(String.t(), optional_string) :: String.t()
  def get_blob_url(name, container \\ nil) do
    "#{Config.api_url()}/#{get_container(container)}/#{name}"
  end

  defp get_container(container \\ nil) do
    case container do
      nil -> Config.default_container()
      _ -> container
    end
  end

end
