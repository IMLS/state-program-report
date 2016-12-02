require_relative '../convert'

describe 'parse_xml' do
  it 'should read a basic example' do
    file = double('asdf')
    allow(file).to receive(:read).and_return('<foo><bar>baz</bar></foo>')
    allow(Zlib::GzipReader).to receive(:open) { |&block| block.call(file) }

    expect(parse_xml('foo.xml.gz')).to eq({'foo' => {'bar' => 'baz'}})
  end
end

describe 'normalize_fsr' do
  it 'should add state to hash' do
    fsr = {}

    result = {
      'State' => 'Minnesota',
    }

    expect(normalize_fsr(fsr, 'Minnesota')).to eq(result)
  end

  it 'should strip out @ from key names' do
    fsr = {
      '@id' => '',
      '@version' => '',
    }

    result = {
      'Id' => '',
      'State' => 'Minnesota',
      'Version' => '',
    }

    expect(normalize_fsr(fsr, 'Minnesota')).to eq(result)
  end
end

describe 'parse_budget_columns' do
  it 'should handle an empty list' do
    expect(parse_budget_columns([])).to eq({'TotalBudget' => nil})
  end

  it 'should handle decimals without rounding errors' do
    budgets = [
      {
        '@type' => '',
        'InKind' => '3.3',
        'Local' => '2.2',
        'LSTA' => '1.1',
      },
      {
        '@type' => '',
        'InKind' => '4.4',
        'Local' => '3.3',
        'LSTA' => '2.2',
      },
    ]

    result = {
      'LSTA' => BigDecimal('2.2'),
      'LSTATotal' => BigDecimal('3.3'),
      'Local' => BigDecimal('3.3'),
      'LocalTotal' => BigDecimal('5.5'),
      'InKind' => BigDecimal('4.4'),
      'InKindTotal' => BigDecimal('7.7'),
      'State' => BigDecimal('0'),
      'StateTotal' => BigDecimal('0'),
      'Other' => BigDecimal('0'),
      'OtherTotal' => BigDecimal('0'),
      'Narrative' => nil,
      'TotalBudget' => BigDecimal('16.5'),
    }

    expect(parse_budget_columns(budgets)).to eq(result)
  end
end

describe 'parse_partner_areas' do
  it 'should handle multiple items' do
    items = ['foo', 'bar']

    result = {
      "PartnerOrganizationArea.1.1" => "foo",
      "PartnerOrganizationArea.1.2" => "bar",
    }

    expect(parse_partner_areas(1, items)).to eq(result)
  end
end

describe 'parse_partner_types' do
  it 'should handle multiple items' do
    items = ['foo', 'bar']

    result = {
      "PartnerOrganizationType.1.1" => "foo",
      "PartnerOrganizationType.1.2" => "bar",
    }

    expect(parse_partner_types(1, items)).to eq(result)
  end
end

describe 'parse_activity_columns' do
  it 'should handle an empty list' do
    activities = []

    result = {'TotalActivities' => 0}

    expect(parse_activity_columns(activities)).to eq(result)
  end

  it 'should number items sequentially' do
    activities = [
      {
        '@id' => 1,
        'Beneficiaries' => {},
        'Locale' => {},
        'Quantity' => [{}],
      },
      {
        '@id' => 2,
        'Beneficiaries' => {},
        'Locale' => {
          'SpecificInstitutions' => {
            'Institution' => [{}]
          }
        },
        'Quantity' => [{}],
      }
    ]

    result = {
      'ActivityAbstract.1' => nil,
      'ActivityAbstract.2' => nil,
      'ActivityFormat.1' => nil,
      'ActivityFormat.2' => nil,
      'ActivityIntent.1' => nil,
      'ActivityIntent.2' => nil,
      'ActivityMode.1' => nil,
      'ActivityMode.2' => nil,
      'ActivityNumber.1' => 1,
      'ActivityNumber.2' => 2,
      'ActivityTitle.1' => nil,
      'ActivityTitle.2' => nil,
      'ActivityType.1' => nil,
      'ActivityType.2' => nil,
      'AgeGroups.1' => nil,
      'AgeGroups.2' => nil,
      'BeneficiariesOther.1' => nil,
      'BeneficiariesOther.2' => nil,
      'BeneficiariesOtherText.1' => nil,
      'BeneficiariesOtherText.2' => nil,
      'Disabilities.1' => nil,
      'Disabilities.2' => nil,
      'EconomicType.1' => nil,
      'EconomicType.2' => nil,
      'EthnicityType.1' => nil,
      'EthnicityType.2' => nil,
      'Families.1' => nil,
      'Families.2' => nil,
      'GeographicCommunity.1' => nil,
      'GeographicCommunity.2' => nil,
      'Immigrants.1' => nil,
      'Immigrants.2' => nil,
      'Intergenerational.1' => nil,
      'Intergenerational.2' => nil,
      'LibraryWorkforce.1' => nil,
      'LibraryWorkforce.2' => nil,
      'Literacy.1' => nil,
      'Literacy.2' => nil,
      'LocaleInstitutionAcademic.1' => nil,
      'LocaleInstitutionAcademic.2' => nil,
      'LocaleInstitutionAddress.2.1' => nil,
      'LocaleInstitutionCity.2.1' => nil,
      'LocaleInstitutionConsortia.1' => nil,
      'LocaleInstitutionConsortia.2' => nil,
      'LocaleInstitutionName.2.1' => nil,
      'LocaleInstitutionOther.1' => nil,
      'LocaleInstitutionOther.2' => nil,
      'LocaleInstitutionPublic.1' => nil,
      'LocaleInstitutionPublic.2' => nil,
      'LocaleInstitutionSchool.1' => nil,
      'LocaleInstitutionSchool.2' => nil,
      'LocaleInstitutionSLAA.1' => nil,
      'LocaleInstitutionSLAA.2' => nil,
      'LocaleInstitutionSpecial.1' => nil,
      'LocaleInstitutionSpecial.2' => nil,
      'LocaleInstitutionState.2.1' => nil,
      'LocaleInstitutionZip.2.1' => nil,
      'LocaleStatewide.1' => nil,
      'LocaleStatewide.2' => nil,
      'OtherModeFormat.1' => nil,
      'OtherModeFormat.2' => nil,
      'QuantityName.1.1' => nil,
      'QuantityName.2.1' => nil,
      'QuantityValue.1.1' => nil,
      'QuantityValue.2.1' => nil,
      'TargetedOrGeneral.1' => nil,
      'TargetedOrGeneral.2' => nil,
      'TotalActivities' => 2,
    }

    expect(parse_activity_columns(activities)).to eq(result)
  end
end

describe 'parse_project_tags' do
  it 'should handle an empty string' do
    expect(parse_project_tags('')).to eq({})
  end

  it 'should sort items' do
    tags = 'beta,gamma,alpha'

    result = {
      'ProjectTag.1' => 'alpha',
      'ProjectTag.2' => 'beta',
      'ProjectTag.3' => 'gamma',
    }

    expect(parse_project_tags(tags)).to eq(result)
  end
end

describe 'parse_links' do
  it 'should handle multiple items' do
    items = ['foo', 'bar']

    result = {
      'LinkURL.1' => 'foo',
      'LinkURL.2' => 'bar',
    }

    expect(parse_links(items)).to eq(result)
  end
end

describe 'parse_intents' do
  it 'should handle missing Subject items' do
    items = [{
      'IntentName' => 'foo',
      'Subject' => [],
    },{
      'IntentName' => 'bar',
      'Subject' => ['baz', 'quux'],
    }]

    result = {
      'IntentName.1' => 'foo',
      'IntentName.2' => 'bar',
      'IntentSubject.1.1' => nil,
      'IntentSubject.1.2' => nil,
      'IntentSubject.2.1' => 'baz',
      'IntentSubject.2.2' => 'quux',
    }

    expect(parse_intents(items)).to eq(result)
  end
end

describe 'normalize_project' do
  it 'should handle an emptyish example' do
    project = {
      'Budgets' => {
        'Budget' => [],
      },
      'Exemplary' => {},
      'Outcomes' => {
        'OutcomeMethods' => {},
      },
    }

    result = {
      'Abstract' => nil,
      'AttachmentCount' => 0,
      'ContinueProject' => nil,
      'ContinueProjectText' => nil,
      'DirectorEmail' => nil,
      'DirectorName' => nil,
      'DirectorPhone' => nil,
      'EffortLevel' => nil,
      'EffortLevelText' => nil,
      'EndDate' => nil,
      'Exemplary' => nil,
      'Findings' => nil,
      'FindingsImportance' => nil,
      'Grantee' => nil,
      'GranteeType' => nil,
      'LessonsLearned' => nil,
      'OtherChange' => nil,
      'OtherChangeText' => nil,
      'OutcomeMethodSurvey' => nil,
      'OutcomeMethodAdminData' => nil,
      'OutcomeMethodFocusGroup' => nil,
      'OutcomeMethodObservation' => nil,
      'OutcomeMethodOther' => nil,
      'ParentProjectId' => nil,
      'ProjectCode' => nil,
      'ProjectID' => nil,
      'ScopeChange' => nil,
      'ScopeChangeText' => nil,
      'StartDate' => nil,
      'State' => 'Minnesota',
      'StateGoal' => nil,
      'StateProjectCode' => nil,
      'Status' => nil,
      'Title' => nil,
      'TotalActivities' => 0,
      'TotalBudget' => nil,
      'Version' => nil,
    }

    expect(normalize_project(project, 'Minnesota')).to eq(result)
  end
end

describe 'convert_hashes' do
  it 'should handle an empty list' do
    expect(convert_hashes([])).to eq([])
  end

  it 'should handle a single item' do
    hashes = [
      {
        'FSR' => {
          '@id' => '',
          '@version' => '',
        },
        'Project' => {
          'Budgets' => {
            'Budget' => [],
          },
          'Exemplary' => {
            'ExemplaryNarrative' => 'foo'
          },
          'Outcomes' => {
            'OutcomeMethods' => {},
          },
        }
      }
    ]
    result = [
      {
        'FSR' => [
          {
            'Id' => '',
            'State' => nil,
            'Version' => '',
          }
        ],
        'Project' => [
          {
            'Abstract' => nil,
            'AttachmentCount' => 0,
            'ContinueProject' => nil,
            'ContinueProjectText' => nil,
            'DirectorEmail' => nil,
            'DirectorName' => nil,
            'DirectorPhone' => nil,
            'EffortLevel' => nil,
            'EffortLevelText' => nil,
            'EndDate' => nil,
            'Exemplary' => "foo\n",
            'Findings' => nil,
            'FindingsImportance' => nil,
            'Grantee' => nil,
            'GranteeType' => nil,
            'LessonsLearned' => nil,
            'OtherChange' => nil,
            'OtherChangeText' => nil,
            'OutcomeMethodSurvey' => nil,
            'OutcomeMethodAdminData' => nil,
            'OutcomeMethodFocusGroup' => nil,
            'OutcomeMethodObservation' => nil,
            'OutcomeMethodOther' => nil,
            'ParentProjectId' => nil,
            'ProjectCode' => nil,
            'ProjectID' => nil,
            'ScopeChange' => nil,
            'ScopeChangeText' => nil,
            'StartDate' => nil,
            'State' => nil,
            'StateGoal' => nil,
            'StateProjectCode' => nil,
            'Status' => nil,
            'Title' => nil,
            'TotalActivities' => 0,
            'TotalBudget' => nil,
            'Version' => nil,
          }
        ]
      }
    ]
    expect(convert_hashes(hashes)).to eq(result)
  end
end

describe 'build_header_list' do
  it 'should handle an empty list' do
    expect(build_header_list([])).to eq({FSR: [], Project: []})
  end

  it 'should handle multiple items' do
    hashes = [
      {
        'FSR' => [
          {'foo' => 'bar'},
          {'baz' => 'quux'},
        ],
        'Project' => [
          {'foo' => 'bar'},
          {'baz' => 'quux'},
        ]
      }
    ]

    result = {
      FSR: %w(baz foo),
      Project: %w(baz foo),
    }

    expect(build_header_list(hashes)).to eq(result)
  end
end

describe 'write_csv' do
  it 'should handle a multiple items' do
    headers = {
        'foo' => %w(a b c)
    }

    states = [
      {
        'foo' => [
          {
            'a' => 1,
            'b' => 2,
            'c' => 3,
          }
        ]
      },
      {
        'foo' => [
          {
            'a' => 4,
            'b' => 5,
            'c' => 6,
          }
        ]
      }
    ]

    allow(File).to receive(:open)
                       .with('generated/test.csv', 'wb', :universal_newline => false)
                       .and_return(StringIO.new)

    expect(write_csv('test.csv', headers, states, 'foo')).to eq(states)
  end
end

describe 'upload_csv' do
  it 'should allow file uploads' do
    contents = double('contents')
    allow(contents).to receive(:create)
                           .with('adhocteam', 'imls-state-program-report', 'data/test.csv',
                                 :path => 'data/test.csv',
                                 :message => 'Automated upload of test.csv',
                                 :content => 'file contents')

    allow(Github::Client::Repos::Contents).to receive(:new).with(:oauth_token => nil).and_return(contents)
    allow(File).to receive(:open) { |&block| block.call(StringIO.new('file contents')) }

    expect(upload_csv('test.csv')).to eq(nil)
  end
end

describe 'parse_file' do
  it 'should fail without a filename' do
    expect(lambda { parse_file }).to raise_error SystemExit
  end

  it 'should not upload without a token' do
    ARGV.push('spec/test.xml.gz')

    expect(self).not_to receive(:upload_csv)

    parse_file
  end

  it 'should convert from gzipped xml to csv' do
    output = StringIO.new
    allow(File).to receive(:open) { |&block| block.call(output) }

    test_xml = Zlib::GzipReader.open('spec/test.xml.gz') { |f|
      Nori.new.parse f.read
    }

    headers = {
      :FSR => [
        'Id',
        'State',
        'Status',
        'Version',
        'FederalGrantNumber',
        'Allotment',
        'RecipientAccountNumber',
        'Basis',
        'FundingPeriodStartDate',
        'FundingPeriodEndDate',
        'ReportPeriodStartDate',
        'ReportPeriodEndDate',
        'StateMOE',
        'MinimumMOERequired',
        'SLAAMatch',
        'OtherMatch',
        'TotalMatch',
        'MinimumMatchRequired',
        'OtherSpecialFunds',
        'TotalUnliquidatedObligations',
        'UnobligatedBalance',
        'LSTANetOutlays',
        'AdminAllowed',
        'AdminActual',
        'AdminDifference',
        'IMLSApprovedDate',
        'NameACO',
        'TitleACO',
        'SignatureACO',
        'PhoneACO',
        'EmailACO',
        'DateReportCertified',
        'AgencyDUNS',
        'AgencyEIN',
        'AgencyName',
      ],
      :Project => [],
    }

    states = [
      {
        'FSR' => [hash_including(*headers[:FSR])],
        'Project' => [],
      },
      {
        'FSR' => [hash_including(*headers[:FSR])],
        'Project' => [],
      }
    ]

    allow(self).to receive(:parse_xml).and_return(test_xml)
    allow(self).to receive(:upload_csv)
    allow(self).to receive(:write_csv).with(/FSR/, headers, states, :FSR)
    allow(self).to receive(:write_csv).with(/Project/, headers, states, :Project)

    ARGV.push('spec/test.xml.gz')
    ENV['GITHUB_TOKEN'] = 'foo'

    parse_file
  end
end
