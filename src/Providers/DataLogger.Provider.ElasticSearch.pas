{
  ********************************************************************************

  Github - https://github.com/dliocode/datalogger

  ********************************************************************************

  MIT License

  Copyright (c) 2022 Danilo Lucas

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.

  ********************************************************************************
}

unit DataLogger.Provider.ElasticSearch;

interface

uses
  DataLogger.Provider, DataLogger.Types,
{$IF DEFINED(DATALOGGER_ELASTICSEARCH_USE_INDY)}
  DataLogger.Provider.REST.Indy,
{$ELSEIF DEFINED(DATALOGGER_ELASTICSEARCH_USE_NETHTTPCLIENT)}
  DataLogger.Provider.REST.NetHTTPClient,
{$ELSE}
  DataLogger.Provider.REST.HTTPClient,
{$ENDIF}
  System.SysUtils, System.JSON;

type
  TProviderElasticSearch = class(TDataLoggerProvider<TProviderElasticSearch>)
  private
    type
    TProviderHTTP = class(
{$IF DEFINED(DATALOGGER_ELASTICSEARCH_USE_INDY)}
      TProviderRESTIndy
{$ELSEIF DEFINED(DATALOGGER_ELASTICSEARCH_USE_NETHTTPCLIENT)}
      TProviderRESTNetHTTPClient
{$ELSE}
      TProviderRESTHTTPClient
{$ENDIF});

  private
    FHTTP: TProviderHTTP;
    FBasicAuthUsername: string;
    FBasicAuthPassword: string;
    FIndex: string;
  protected
    procedure Save(const ACache: TArray<TLoggerItem>); override;
  public
    function URL(const AValue: string): TProviderElasticSearch;
    function BasicAuth(const AUsername: string; const APassword: string): TProviderElasticSearch;
    function Index(const AValue: string): TProviderElasticSearch;

    procedure LoadFromJSON(const AJSON: string); override;
    function ToJSON(const AFormat: Boolean = False): string; override;

    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TProviderElasticSearch }

constructor TProviderElasticSearch.Create;
begin
  inherited Create;

  FHTTP := TProviderHTTP.Create;
  FHTTP.ContentType('application/json');
  FHTTP.URL('https://localhost:9200');

  Index('logger');

  SetIgnoreLogFormat(True);
end;

destructor TProviderElasticSearch.Destroy;
begin
  FHTTP.Free;
  inherited;
end;

function TProviderElasticSearch.URL(const AValue: string): TProviderElasticSearch;
begin
  Result := Self;
  FHTTP.URL(AValue);
end;

function TProviderElasticSearch.BasicAuth(const AUsername: string; const APassword: string): TProviderElasticSearch;
begin
  Result := Self;

  FBasicAuthUsername := AUsername;
  FBasicAuthPassword := APassword;

  FHTTP.BasicAuth(AUsername, APassword);
end;

function TProviderElasticSearch.Index(const AValue: string): TProviderElasticSearch;
begin
  Result := Self;
  FIndex := AValue;
end;

procedure TProviderElasticSearch.LoadFromJSON(const AJSON: string);
var
  LJO: TJSONObject;
begin
  if AJSON.Trim.IsEmpty then
    Exit;

  try
    LJO := TJSONObject.ParseJSONValue(AJSON) as TJSONObject;
  except
    on E: Exception do
      Exit;
  end;

  if not Assigned(LJO) then
    Exit;

  try
    URL(LJO.GetValue<string>('url', FHTTP.URL));
    BasicAuth(LJO.GetValue<string>('basic_auth_username', FBasicAuthUsername), LJO.GetValue<string>('basic_auth_password', FBasicAuthPassword));
    Index(LJO.GetValue<string>('index', FIndex));

    SetJSONInternal(LJO);
  finally
    LJO.Free;
  end;
end;

function TProviderElasticSearch.ToJSON(const AFormat: Boolean): string;
var
  LJO: TJSONObject;
begin
  LJO := TJSONObject.Create;
  try
    LJO.AddPair('url', FHTTP.URL);
    LJO.AddPair('basic_auth_username', FBasicAuthUsername);
    LJO.AddPair('basic_auth_password', FBasicAuthPassword);
    LJO.AddPair('index', FIndex);

    ToJSONInternal(LJO);

    Result := TLoggerJSON.Format(LJO, AFormat);
  finally
    LJO.Free;
  end;
end;

procedure TProviderElasticSearch.Save(const ACache: TArray<TLoggerItem>);
var
  LItemREST: TArray<TLogItemREST>;
  LItem: TLoggerItem;
  LLogItemREST: TLogItemREST;
begin
  LItemREST := [];

  if Length(ACache) = 0 then
    Exit;

  for LItem in ACache do
  begin
    if LItem.InternalItem.LevelSlineBreak then
      Continue;

    LLogItemREST.Stream := TLoggerLogFormat.AsStreamJsonObject(FLogFormat, LItem, FFormatTimestamp, FIgnoreLogFormat);
    LLogItemREST.LogItem := LItem;
    LLogItemREST.URL := Format('%s/%s/_doc', [FHTTP.URL.Trim(['/']), FIndex.ToLower]);

    LItemREST := Concat(LItemREST, [LLogItemREST]);
  end;

  FHTTP.InternalSaveAsync(TRESTMethod.tlmPost, LItemREST);
end;

procedure ForceReferenceToClass(C: TClass);
begin
end;

initialization

ForceReferenceToClass(TProviderElasticSearch);

end.
