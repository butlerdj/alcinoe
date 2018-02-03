unit SmartTests;

interface

uses 
  SmartCL.System,
  System.Types,
  ECMA.Date,
  System.Date,
  SynCrossPlatformSpecific,
  SynCrossPlatformREST,
  SynCrossPlatformCrypto;

procedure TestSMS;

procedure ORMTest(client: TSQLRestClientURI);

procedure SOATest(client: TSQLRestClientURI; onSuccess, onError: TSQLRestEvent);

implementation

uses
  mORMotClient; // unit generated by the server!

const
  MSecsPerDay = 86400000;
  OneSecDateTime = 1/SecsPerDay;

procedure TestsIso8601DateTime;
  procedure Test(D: TDateTime);
  var s: string;
  procedure One(D: TDateTime);
  var E: TDateTime;
      V: TTimeLog;
      J: JDate;
  begin
    J := new JDate;
    J.AsDateTime := D;
    E := J.AsDateTime;
    assert(Abs(D-E)<OneSecDateTime);
    s := DateTimeToIso8601(D);
    E := Iso8601ToDateTime(s);
    assert(Abs(D-E)<OneSecDateTime);
    V := DateTimeToTTimeLog(D);
    E := TTimeLogToDateTime(V);
    assert(Abs(D-E)<OneSecDateTime);
    assert(UrlDecode(UrlEncode(s))=s);
  end;
  begin
    One(D);
    assert(length(s)=19);
    One(Trunc(D));
    assert(length(s)=10);
    One(Frac(D));
    assert(length(s)=9);
  end;
var D: TDateTime;
    i: integer;
    s,x: string;
    T: TTimeLog;
begin
  s := '2014-06-28T11:50:22';
  D := Iso8601ToDateTime(s);
  assert(DateTimeToIso8601(D)=s);
  assert(Abs(D-41818.40997685185)<OneSecDateTime);
  x := TTimeLogToIso8601(135181810838);
  assert(x=s);
  T := DateTimeToTTimeLog(D);
  assert(T=135181810838);
  D := Now/20+Random*20; // some starting random date/time
  for i := 1 to 2000 do begin
    Test(D);
    D := D+Random*57; // go further a little bit: change date/time
  end;
end;

procedure TestSMS;
var doc: TJSONVariantData;
begin
  assert(crc32ascii(0,'abcdefghijklmnop')=$943AC093);
  assert(SHA256('abc')='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  assert(VariantType(123)=jvUndefined);
  assert(VariantType(null)=jvUndefined);
  assert(VariantType(TVariant.CreateObject)=jvObject);
  assert(VariantType(new JObject)=jvObject);
  assert(VariantType(TVariant.CreateArray)=jvArray);
  doc := TJSONVariantData.Create('{"a":1,"b":"B"}');
  assert(doc.Kind=jvObject);
  assert(doc.Count=2);
  assert(doc.Names[0]='a');
  assert(doc.Names[1]='b');
  assert(doc.Values[0]=1);
  assert(doc.Values[1]='B');
  doc := TJSONVariantData.Create('["a",2]');
  assert(doc.Kind=jvArray);
  assert(doc.Count=2);
  assert(doc.Names.Count=0);
  assert(doc.Values[0]='a');
  assert(doc.Values[1]=2);
  TestsIso8601DateTime;
end;


procedure ORMTest(client: TSQLRestClientURI);
var people: TSQLRecordPeople;
    Call: TSQLRestURIParams;
    res: TIntegerDynArray;
    i,id: integer;
begin // all this is run in synchronous mode -> only 200 records in the set
  client.CallBackGet('DropTable',[],Call,TSQLRecordPeople);
  assert(client.InternalState>0);
  assert(Call.OutStatus=HTTP_SUCCESS);
  client.BatchStart(TSQLRecordPeople);
  people := TSQLRecordPeople.Create;
  assert(people.InternalState=0);
  for i := 1 to 200 do begin
    people.FirstName := 'First'+IntToStr(i);
    people.LastName := 'Last'+IntToStr(i);
    people.YearOfBirth := i+1800;
    people.YearOfDeath := i+1825;
    assert(client.BatchAdd(people,true)=i-1);
    assert(people.InternalState=0);
  end;
  assert(client.BatchSend(res)=HTTP_SUCCESS);
  assert(length(res)=200);
  for i := 1 to 200 do
    assert(res[i-1]=i);
  people := TSQLRecordPeople.CreateAndFillPrepare(client,'','',[]);
  assert(people.InternalState=0);
  id := 0;
  while people.FillOne do begin
    assert(people.InternalState=client.InternalState);
    inc(id);
    assert(people.ID=id);
    assert(people.FirstName='First'+IntToStr(id));
    assert(people.LastName='Last'+IntToStr(id));
    assert(people.YearOfBirth=id+1800);
    assert(people.YearOfDeath=id+1825);
  end;
  assert(id=200);
  people.Free; // release all memory used by the request
  people := TSQLRecordPeople.CreateAndFillPrepare(client,
    'YearOFBIRTH,Yearofdeath,id','',[]);
  assert(people.InternalState=0);
  id := 0;
  while people.FillOne do begin
    assert(people.InternalState=client.InternalState);
    inc(id);
    assert(people.ID=id);
    assert(people.FirstName='');
    assert(people.LastName='');
    assert(people.YearOfBirth=id+1800);
    assert(people.YearOfDeath=id+1825);
  end;
  assert(id=200);
  people.Free; // release all memory used by the request
  people := TSQLRecordPeople.CreateAndFillPrepare(client,'',
    'yearofbirth=?',[1900]);
  id := 0;
  while people.FillOne do begin
    assert(people.InternalState=client.InternalState);
    inc(id);
    assert(people.ID=100);
    assert(people.FirstName='First100');
    assert(people.LastName='Last100');
    assert(people.YearOfBirth=1900);
    assert(people.YearOfDeath=1925);
  end;
  assert(id=1);
  for i := 1 to 200 do
    if i and 15=0 then
      client.Delete(TSQLRecordPeople,i) else
    if i mod 82=0 then begin
      people := TSQLRecordPeople.Create;
      id := i+1;
      people.ID := i;
      people.FirstName := 'neversent';
      people.LastName := 'neitherthisone';
      people.YearOfBirth := id+1800;
      people.YearOfDeath := id+1825;
      assert(people.InternalState=0);
      assert(client.Update(people,'YEarOFBIRTH,YEarOfDeath'));
      assert(people.InternalState=client.InternalState);
  end;
  people := new TSQLRecordPeople;
  assert(people.InternalState=0);
  for i := 1 to 200 do begin
    var read = client.Retrieve(i,people);
    if i and 15=0 then
      assert(not read) else begin
      assert(read);
      assert(people.InternalState=client.InternalState);
      if i mod 82=0 then
        id := i+1 else
        id := i;
      assert(people.ID=i);
      assert(people.FirstName='First'+IntToStr(i));
      assert(people.LastName='Last'+IntToStr(i));
      assert(people.YearOfBirth=id+1800);
      assert(people.YearOfDeath=id+1825);
    end;
  end;
  people.Free;
end;

procedure SOATest(client: TSQLRestClientURI; onSuccess, onError: TSQLRestEvent);
var Calc: TServiceCalculator;
    i: integer;
const SEX_TEXT: array[0..1] of string = ('Miss','Mister');
      ITERATIONS = 50;
begin
  Calc := TServiceCalculator.Create(client); // no need to free instance on SMS
  assert(Calc.InstanceImplementation=sicShared);
  assert(Calc.ServiceName='Calculator');
  // first test synchronous / blocking mode
  for i := 1 to ITERATIONS do
    assert(calc._Add(i,i+1)=i*2+1);
  for i := 1 to ITERATIONS do begin
    var sex := TPeopleSexe(i and 1);
    var name := 'Smith';
    calc._ToText(i,'$',sex,name);
    assert(sex=sFemale);
    assert(name=format('$ %d for %s Smith',[i,SEX_TEXT[i and 1]]));
  end;
  var j: integer;
  var rec: TTestCustomJSONArraySimpleArray;
  for i := 1 to ITERATIONS do begin
    var name := calc._RecordToText(rec);
    if i=1 then
      assert(name='{"F":"","G":[],"H":{"H1":0,"H2":"","H3":{"H3a":false,"H3b":null}},"I":"","J":[]}');
    assert(length(Rec.F)=i);
    for j := 1 to length(Rec.F) do
      assert(Rec.F[j]='!');
    assert(length(Rec.G)=i);
    for j := 0 to high(Rec.G) do
      assert(Rec.G[j]=IntToStr(j+1));
    assert(Rec.H.H1=i);
    assert(length(Rec.J)=i-1);
    for j := 0 to high(Rec.J) do begin
      assert(Rec.J[j].J1=j);
      assert(Rec.J[j].J2<>'');
      assert(Rec.J[j].J3=TRecordEnum(j mod (ord(high(TRecordEnum))+1)));
    end;
  end;
  // code below is asynchronous, so more difficult to follow than synchronous !
  i := 1;  // need two Calc*Asynch() inlined lambdas to access var i
  procedure CalcToTextAsynch(sexe: TPeopleSexe; name: string);
  begin
    assert(sexe=sFemale);
    assert(name=format('$ %d for %s Smith',[i,SEX_TEXT[i and 1]]));
    inc(i);
    sexe := TPeopleSexe(i and 1);
    name := 'Smith';
    if i<=ITERATIONS then // recursive for i := 1 to ITERATIONS
      Calc.ToText(i,'$',sexe,name,CalcToTextAsynch,onError) else
      onSuccess(client);
  end;
  procedure CalcAddAsynch(res: integer);
  begin
    assert(res=i*2+1);
    inc(i);
    if i<=ITERATIONS then // recursive for i := 1 to ITERATIONS
      Calc.Add(i,i+1,CalcAddAsynch,onError) else begin
      i := 1;
      Calc.ToText(i,'$',TPeopleSexe(i and 1),'Smith',CalcToTextAsynch,onError);
    end;
  end;
  Calc.Add(i,i+1,CalcAddAsynch,onError);
end;

end.