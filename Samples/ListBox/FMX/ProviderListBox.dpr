program ProviderListBox;

uses
  System.StartUpCopy,
  FMX.Forms,
  UProviderListBox in 'UProviderListBox.pas' {Form2};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
