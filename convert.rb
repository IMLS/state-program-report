#!/usr/bin/env ruby

# This script takes a deeply nested gzipped XML file and converts it
# to a wide CSV file. It then uploads the resulting CSV file to Github.
# Github credentials should be made available via the environment
# variable `GITHUB_TOKEN`, and the gzipped XML filename should be made
# available as the first command-line argument to this script.

# stdlib requires
require 'csv'
require 'date'
require 'set'
require 'zlib'

# Gem requires
require 'github_api'
require 'nori'
require 'tidy_ffi'


# Parses the zipped XML file into a nested Hash. Removes all numeric
# code character entities, as they cause the nori parser to break in
# weird ways:
# https://github.com/savonrb/nori/issues/71
def parse_xml(filename)
  Zlib::GzipReader.open(filename, encoding: "BINARY") { |f|
    Nori.new.parse f.read.gsub /&#x[a-zA-Z0-9]{2};/, ''
  }
end

# Takes an object that may be a list, a single element, or `nil`, and ensures
# that it's respectively either the same list, a list containing the single
# element, or an empty list. Copied from Rails:
# https://github.com/rails/rails/blob/master/activesupport/lib/active_support/core_ext/array/wrap.rb#L37
def to_list(object)
  if object.nil?
    []
  elsif object.respond_to?(:to_ary)
    object.to_ary || [object]
  else
    [object]
  end
end

# Tidies XML fields
def tidy(xml)
  return nil if xml.nil?

  tidy = TidyFFI::Tidy.new(xml.force_encoding(Encoding::UTF_8))

  tidy.options.bare = 'yes'
  tidy.options.clean = 'yes'
  tidy.options.show_body_only = 'yes'
  tidy.options.drop_proprietary_attributes = 'yes'
  tidy.options.hide_comments = 'yes'
  tidy.options.show_body_only = 'yes'
  tidy.options.word_2000 = 'yes'

  cleaned_xml = tidy.clean

  return nil if cleaned_xml.nil?

  cleaned_xml.force_encoding(Encoding::UTF_8)
end

# Normalizes the FSR entries. Adds state, converts nested comment
# hash to separate entries, and removes `@` from key names.
# Modifies the hash in-place.
def normalize_fsr(fsr, state)
  fsr['state'] = state
  fsr.delete 'Comment'

  # Remove `@` symbols and capitalize first letter
  fsr.map { |k, v| [k.gsub('@', '').sub(/^./, &:upcase), v] }.to_h
end

# Calculate budget totals. Uses `BigDecimal` over floats
# to avoid rounding errors.
def parse_budget_columns(budget_list)
  totals = budget_list.reduce(Hash.new(0)) do |memo, budget|
    {
      'LSTATotal' => 'LSTA',
      'StateTotal' => 'Match_State',
      'OtherTotal' => 'Match_Other',
      'LocalTotal' => 'Local',
      'InKindTotal' => 'InKind',
    }.each { |k, v| memo[k] += BigDecimal(budget[v] || '0') }

    memo
  end

  itemized = budget_list.map do |budget|
    budget_type_key = budget['@type'].gsub(/\s/, '').gsub(/\/.*/, '')

    {
      "LSTA#{budget_type_key}" => BigDecimal(budget['LSTA'] || '0'),
      "State#{budget_type_key}" => BigDecimal(budget['Match_State'] || '0'),
      "Other#{budget_type_key}" => BigDecimal(budget['Match_Other'] || '0'),
      "Local#{budget_type_key}" => BigDecimal(budget['Local'] || '0'),
      "InKind#{budget_type_key}" => BigDecimal(budget['InKind'] || '0'),
      "Narrative#{budget_type_key}" => budget['Narrative'],
    }
  end.reduce(&:merge) || {}

  totals['TotalBudget'] = totals.values.reduce(:+)

  totals.merge(itemized)
end

# Creates a numbered list of quantity columns.
def parse_quantities(id, quantities)
  quantities.each.with_index(1).map do |quantity, j|
    {
      "QuantityName" => quantity['QuantityName'],
      "QuantityValue" => quantity['QuantityValue'],
    }.map { |k, v| ["#{k}.#{id}.#{j}", v] }.to_h
  end.reduce(&:merge) || {}
end

# Creates a numbered list of institution columns.
def parse_institutions(id, institutions)
  institutions.each.with_index(1).map do |institution, j|
    {
      "LocaleInstitutionName" => institution['Name'],
      "LocaleInstitutionAddress" => institution['Address'],
      "LocaleInstitutionCity" => institution['City'],
      "LocaleInstitutionState" => institution['State'],
      "LocaleInstitutionZip" => institution['Zip'],
    }.map { |k, v| ["#{k}.#{id}.#{j}", v] }.to_h
  end.reduce(&:merge) || {}
end

# Creates a numbered list of partner area columns.
def parse_partner_areas(id, partner_areas)
  partner_areas.each.with_index(1).map do |area, j|
    {
      "PartnerOrganizationArea" => area,
    }.map { |k, v| ["#{k}.#{id}.#{j}", v] }.to_h
  end.reduce(&:merge) || {}
end

# Creates a numbered list of partner type columns.
def parse_partner_types(id, partner_types)
  partner_types.each.with_index(1).map do |type, j|
    {
      "PartnerOrganizationType" => type,
    }.map { |k, v| ["#{k}.#{id}.#{j}", v] }.to_h
  end.reduce(&:merge) || {}
end

# Handles parsing of `ProjectActivity` fields.
def parse_activity_columns(activities)
  activities_total = [{'TotalActivities' => activities.length}]

  activities_list = activities.map do |activity|
    id = activity['@id']

    quantities = parse_quantities id, to_list(activity['Quantity'])
    institutions = parse_institutions id, to_list(((activity['Locale'] || {})['SpecificInstitutions'] || {})['Institution'])
    partner_areas = parse_partner_areas id, to_list((activity['Partners'] || {})['OrganizationArea'])
    partner_types = parse_partner_types id, to_list((activity['Partners'] || {})['OrganizationType'])
    institution_types = activity['Locale'].fetch('InstitutionTypes', {})

    activity_hash = {
      "ActivityNumber" => id,
      "ActivityTitle" => activity['Title'],
      "ActivityAbstract" => tidy(activity['Abstract']),
      "ActivityIntent" => activity['ActivityIntent'],
      "ActivityType" => activity['Activity'],
      "ActivityMode" => activity['Mode'],
      "ActivityFormat" => activity['Format'],
      "OtherModeFormat" => activity['OtherModeFormat'],

      # Beneficiaries
      "LibraryWorkforce" => activity['Beneficiaries']['LibraryWorkforce'],
      "TargetedOrGeneral" => activity['Beneficiaries']['TargetedOrGeneral'],
      "GeographicCommunity" => activity['Beneficiaries']['GeographicCommunity'],
      "AgeGroups" => activity['Beneficiaries']['AgeGroups'],
      "EconomicType" => activity['Beneficiaries']['EconomicType'],
      "EthnicityType" => activity['Beneficiaries']['EthnicityType'],
      "Families" => activity['Beneficiaries']['Families'],
      "Intergenerational" => activity['Beneficiaries']['Intergenerational'],
      "Immigrants" => activity['Beneficiaries']['Immigrants'],
      "Disabilities" => activity['Beneficiaries']['Disabilities'],
      "Literacy" => activity['Beneficiaries']['Literacy'],
      "BeneficiariesOther" => activity['Beneficiaries']['BeneficiariesOther'],
      "BeneficiariesOtherText" => activity['Beneficiaries']['BeneficiariesOtherText'],

      # Locale
      "LocaleStatewide" => activity['Locale']['@stateWide'],
      "LocaleInstitutionPublic" => institution_types['InstitutionTypePublic'],
      "LocaleInstitutionAcademic" => institution_types['InstitutionTypeAcademic'],
      "LocaleInstitutionSLAA" => institution_types['InstitutionTypeSLAA'],
      "LocaleInstitutionConsortia" => institution_types['InstitutionTypeConsortia'],
      "LocaleInstitutionSpecial" => institution_types['InstitutionTypeSpecial'],
      "LocaleInstitutionSchool" => institution_types['InstitutionTypeSchool'],
      "LocaleInstitutionOther" => institution_types['InstitutionTypeOther'],
    }.map { |k, v| ["#{k}.#{id}", v] }.to_h


    [
      activity_hash,
      quantities,
      institutions,
      partner_areas,
      partner_types,
    ].reduce(&:merge)
  end

  (activities_total + activities_list).reduce(&:merge) || {}
end

# The `<ProjectTags>` element is listed in the XSD file as just a string,
# but it is actually a comma-separated list of tags, so we split it up
# into ProjectTag.X columns here.
def parse_project_tags(tags)
  tags.split(',').sort.each.with_index(1).map do |name, i|
    {
      "ProjectTag.#{i}" => name,
    }
  end.reduce(&:merge) || {}
end

# Creates a numbered list of `LinkURL.X` columns.
def parse_links(links)
  links.each.with_index(1).map do |link, i|
    {
      "LinkURL.#{i}" => link,
    }
  end.reduce(&:merge) || {}
end

# Creates a numbered list of `IntentName.X` columns, along with the
# corresponding `IntentSubject.X.Y` columns. The XSD file specifies a
# maximum of two `<IntentSubject>` elements per `<Intent>` element, so
# they're just hardcoded.
def parse_intents(intents)
  intents.each.with_index(1).map do |intent, i|
    {
      "IntentName.#{i}" => intent['IntentName'],
      "IntentSubject.#{i}.1" => intent['Subject'][0],
      "IntentSubject.#{i}.2" => intent['Subject'][1],
    }
  end.reduce(&:merge) || {}
end

# Provides explicit mapping from parsed Project hashes to normalized
# hashes. Returns a new hash instead of modifying the existing one.
def normalize_project(project, state)
  # Use of `(foo['bar'] || {})` as opposed to `foo.fetch('bar', {})` is due
  # to the possibility of the key being set to just `nil`, instead of unset.
  totals = parse_budget_columns project['Budgets']['Budget']
  tags = parse_project_tags project['ProjectTags'] || ''
  links = parse_links to_list (project['AdditionalMaterials'] || {})['LinkURL']
  intents = parse_intents to_list (project['Intents'] || {})['Intent']
  activities = parse_activity_columns to_list (project['ProjectActivities'] || {})['ProjectActivity']

  outcome_methods = project['Outcomes']['OutcomeMethods'] || {}
  grantee = project['Grantee'] || {}

  grantee_address = if grantee['Address1'].nil?
    nil
  else
    "#{grantee['Address1']} #{grantee['Address2']} #{grantee['Address3']} " +
    "#{grantee['City']}, #{grantee['State']} #{grantee['Zip']}"
  end

  project_hash = {
    'ProjectID' => project['@id'],
    'ProjectCode' => project['@sprProjectCode'],
    'Version' => project['@version'],
    'Status' => project['@status'],
    'State' => state,
    'Title' => project['Title'],
    'StateProjectCode' => project['StateProjectCode'],
    'ParentProjectId' => project['ParentProjectId'],
    'StartDate' => project['StartDate'],
    'EndDate' => project['EndDate'],
    'StateGoal' => project['StateGoal'],
    'Abstract' => tidy(project['Abstract']),
    'AttachmentCount' => ((project['AdditionalMaterials'] || {})['FileName'] || {}).length,
    'DirectorName' => (project['Director'] || {})['Name'],
    'DirectorPhone' => (project['Director'] || {})['Phone'],
    'DirectorEmail' => (project['Director'] || {})['Email'],
    'Grantee' => grantee['Name'],
    'GranteeAddress' => grantee_address,
    'GranteeAddress1' => grantee['Address1'],
    'GranteeAddress2' => grantee['Address2'],
    'GranteeAddress3' => grantee['Address3'],
    'GranteeCity' => grantee['City'],
    'GranteeState' => grantee['State'],
    'GranteeZip' => grantee['Zip'],
    'GranteeType' => grantee['Type'],  # Only found in FY13 XML file
    'PlsId' => grantee['PlsId'],
    'IpedsId' => grantee['IpedsId'],
    'CommonCoreId' => grantee['CommonCoreId'],
    'Findings' => project['Outcomes']['Findings'],
    'FindingsImportance' => project['Outcomes']['FindingsImportance'],
    'OutcomeMethodSurvey' => outcome_methods['OutcomeMethodSurvey'],
    'OutcomeMethodAdminData' => outcome_methods['OutcomeMethodAdminData'],
    'OutcomeMethodFocusGroup' => outcome_methods['OutcomeMethodFocusGroup'],
    'OutcomeMethodObservation' => outcome_methods['OutcomeMethodObservation'],
    'OutcomeMethodOther' => outcome_methods['OutcomeMethodOther'],
    'LessonsLearned' => project['Outcomes']['LessonsLearned'],
    'ContinueProject' => project['Outcomes']['ContinueProject'],
    'ContinueProjectText' => project['Outcomes']['ContinueProjectText'],
    'EffortLevel' => project['Outcomes']['EffortLevel'],
    'EffortLevelText' => project['Outcomes']['EffortLevelText'],
    'ScopeChange' => project['Outcomes']['ScopeChange'],
    'ScopeChangeText' => project['Outcomes']['ScopeChangeText'],
    'OtherChange' => project['Outcomes']['OtherChange'],
    'OtherChangeText' => project['Outcomes']['OtherChangeText'],
    'Exemplary' => tidy(project['Exemplary']['ExemplaryNarrative']),
  }

  return [
    project_hash,
    totals,
    activities,
    tags,
    links,
    intents,
  ].reduce(&:merge)
end

# Takes the nested hashes that were parsed from the XML and creates
# a regularized structure similar to:
#
# states = [{
#   'FSR': [{...}, {...}],
#   'Projects': [{...}, {...}],
# },
# ...
# ]
def convert_hashes(states)
  states.map do |s|
    s.reduce({}) do |state, (key, value)|
      case key
        when 'FSR'
          state['FSR'] = to_list(value).map { |fsr|
            normalize_fsr(fsr, s['@state'])
          }
        when 'Project'
          state['Project'] = to_list(value).map { |project|
            normalize_project(project, s['@state'])
          }
        else
          # Ignore AdminProject, @state and other keys
      end

      # Force each list to be an empty list, if not defined.
      state['FSR'] ||= []
      state['Project'] ||= []
      state
    end
  end
end

# Canonical ordering of CSV columns. Some columns are ordered in a special
# manner. For example, `foo.X`, `bar.X`, and `baz.X` should be ordered as
# `foo.1`, `bar.1`, `baz.1`, `foo.2`, `bar.2`, `baz.2`, etc. This is
# accomplished by putting all such columns in a list together below.
SORTING = {
  'FSR' => [
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
    'Note',
  ],
  'Project' => [
    'ProjectID',
    'Version',
    'Status',
    'ProjectCode',
    'State',
    'Title',
    'StateProjectCode',
    'ParentProjectId',
    'StartDate',
    'EndDate',
    'StateGoal',
    'Abstract',
    'AttachmentCount',
    'DirectorName',
    'DirectorPhone',
    'DirectorEmail',
    'Grantee',
    'GranteeType',
    'PlsId',
    'IpedsId',
    'CommonCoreId',
    'LinkURL',
    [
      'IntentName',
      'IntentSubject',
    ],
    'InKindConsultantFees',
    'InKindEquipment',
    'InKindOtherOperationalExpenses',
    'InKindSalaries',
    'InKindServices',
    'InKindSupplies',
    'InKindTravel',
    'LSTAConsultantFees',
    'LSTAEquipment',
    'LSTAOtherOperationalExpenses',
    'LSTASalaries',
    'LSTAServices',
    'LSTASupplies',
    'LSTATravel',
    'LocalConsultantFees',
    'LocalEquipment',
    'LocalOtherOperationalExpenses',
    'LocalSalaries',
    'LocalServices',
    'LocalSupplies',
    'LocalTravel',
    'OtherConsultantFees',
    'OtherEquipment',
    'OtherOtherOperationalExpenses',
    'OtherSalaries',
    'OtherServices',
    'OtherSupplies',
    'OtherTravel',
    'NarrativeConsultantFees',
    'NarrativeEquipment',
    'NarrativeOtherOperationalExpenses',
    'NarrativeSalaries',
    'NarrativeServices',
    'NarrativeSupplies',
    'NarrativeTravel',
    'StateConsultantFees',
    'StateEquipment',
    'StateOtherOperationalExpenses',
    'StateSalaries',
    'StateServices',
    'StateSupplies',
    'StateTravel',
    'LSTATotal',
    'StateTotal',
    'OtherTotal',
    'LocalTotal',
    'InKindTotal',
    'TotalBudget',
    'Findings',
    'FindingsImportance',
    'OutcomeMethodSurvey',
    'OutcomeMethodAdminData',
    'OutcomeMethodFocusGroup',
    'OutcomeMethodObservation',
    'OutcomeMethodOther',
    'LessonsLearned',
    'ContinueProject',
    'ContinueProjectText',
    'EffortLevel',
    'EffortLevelText',
    'ScopeChange',
    'ScopeChangeText',
    'OtherChange',
    'OtherChangeText',
    'Exemplary',
    'ProjectTag',
    'TotalActivities',
    [
      'ActivityNumber',
      'ActivityTitle',
      'ActivityAbstract',
      'ActivityIntent',
      'ActivityType',
      'ActivityMode',
      'ActivityFormat',
      'OtherModeFormat',
      [
        'QuantityName',
        'QuantityValue',
      ],
      [
        'PartnerOrganizationArea',
        'PartnerOrganizationType',
      ],
      'LibraryWorkforce',
      'TargetedOrGeneral',
      'GeographicCommunity',
      'AgeGroups',
      'EconomicType',
      'EthnicityType',
      'Families',
      'Intergenerational',
      'Immigrants',
      'Disabilities',
      'Literacy',
      'BeneficiariesOther',
      'BeneficiariesOtherText',
      'LocaleStatewide',
      [
        'LocaleInstitutionName',
        'LocaleInstitutionAddress',
        'LocaleInstitutionCity',
        'LocaleInstitutionState',
        'LocaleInstitutionZip',
        'LocaleInstitutionPublic',
        'LocaleInstitutionAcademic',
        'LocaleInstitutionSLAA',
        'LocaleInstitutionConsortia',
        'LocaleInstitutionSpecial',
        'LocaleInstitutionSchool',
        'LocaleInstitutionOther',
      ],
    ],
  ]
}

# Convenience function that handles special ordering of nested elements.
def order(col_name, index, sorting)
  # Turn 'foo.1.2' into `name = 'foo'`, `major = 1`, and `minor = 2`.
  # Pad the results so that for something like `foo.1`, `minor` will
  # just be `0`.
  name, *nums = col_name.split('.')
  major, minor = (nums.map(&:to_i) + [0, 0])[0..1]

  # Handle an element located in an ordering sublist
  if sorting[index].is_a? Array
    sub_index = sorting[index].index do |i|
      if i.is_a? Array then i.include? name else name == i end
    end

    # Handle an element located in an ordering subsublist.
    # Beyond this is forbidden. Do not attempt it.
    if sorting[index][sub_index].is_a? Array
      sub_sub_index = sorting[index][sub_index].index name

      [index, major, sub_index, minor, sub_sub_index]
    else
      [index, major, sub_index]
    end
  else
    [index]
  end
end

# Helper method for sorting columns according to the original XML ordering.
# We lose that information due to the unordered nature of Ruby's hashes, so
# we explicitly provide an ordering for this function.
def sort_columns(x, y, key)
  # Look for the index of `x` and `y`. Since they can be numbered like
  # `ProjectTag.1`, declare it a match if `x` or `y` simply start with
  # the element. Also handle sublists of elements that should be grouped
  # together in the ordering.
  x_index = SORTING[key].index do |i|
    col_name = x.sub(/\..*/, '')
    if i.is_a? Array then i.flatten.include? col_name else col_name == i end
  end

  y_index = SORTING[key].index do |i|
    col_name = y.sub(/\..*/, '')
    if i.is_a? Array then i.flatten.include? col_name else col_name == i end
  end

  # Gracefully handle missing items, putting them at the end of
  # the ordering. All such items are alphabetized.
  case [x_index.nil?, y_index.nil?]
  when [true,   true] then x <=> y
  when [true,  false] then  1
  when [false,  true] then -1
  when [false, false]
    # If both items map to the same ordering index (e.g. `ActivityNumber.1`
    # and `ActivityNumber.2`), order alphabetically.
    case x_index <=> y_index
    when -1 then -1
    when  1 then  1
    when  0 then order(x, x_index, SORTING[key]) <=> order(y, y_index, SORTING[key])
    end
  end
end

# Builds a complete list of sorted headers to include in the
# CSV. Since not all `Project` hashes have all of the headers,
# we have to iterate over all of them and built a complete list.
def build_header_list(states)
  {
    'FSR': states.reduce(Set.new) do |memo, s|
      memo + s['FSR'].reduce(Set.new) do |m, f|
        m + f.keys.to_set
      end
    end.to_a.sort { |x, y| sort_columns(x, y, 'FSR') },
    'Project': states.reduce(Set.new) do |memo, s|
      memo + s['Project'].reduce(Set.new) do |m, p|
        m + p.keys.to_set
      end
    end.to_a.sort { |x, y| sort_columns(x, y, 'Project') },
  }
end

# Writes the hashes out to a CSV file
def write_csv(filename, headers, states, key, directory)
  CSV.open("#{directory}/#{filename}", 'wb') do |csv|
    csv << headers[key]

    states.each do |state|
      state[key.to_s].each do |hash|
        csv << headers[key].map { |k| hash[k].to_s.gsub(/\n/, ' ') }
      end
    end
  end
end

def write_state_csvs(states, directory, fiscal_year, now)
  states.each do |state|
    # Skip creating the CSV if the state didn't have any projects
    next unless state['Project'][0]

    state_name = state['Project'][0]['State']
    filename = "Projects-#{state_name}-FY#{fiscal_year}-#{now}.csv"

    headers = state['Project'].reduce(Set.new) do |memo, p|
      memo + p.keys.to_set
    end

    CSV.open("#{directory}/#{filename}", 'wb') do |csv|
      csv << headers

      state['Project'].each do |hash|
        csv << headers.map { |k| hash[k].to_s.gsub(/\n/, ' ') }
      end
    end
  end
end

# Uploads file to Github
def upload_zip(filename)
  contents = Github::Client::Repos::Contents.new oauth_token: ENV['GITHUB_TOKEN']

  File.open("generated/#{filename}", 'r') do |f|
    contents.create 'IMLS',
                    'state-program-report-data',
                    "reports/#{filename}",
                    path: "reports/#{filename}",
                    message: "Automated upload of #{filename}",
                    content: f.read
  end
end

# Main entrypoint for script.
def parse_file
  # Ensure that a filename was passed in
  if ARGV.empty?
    puts 'A filename for parsing is required!'
    exit(1)
  end

  doc = parse_xml ARGV[0]

  if doc['ImlsExport'] == nil
    puts 'There was an error parsing the document!'
    puts "Expected to find 'ImlsExport', found `#{doc.keys.inspect}` instead."
    exit(1)
  end

  # Create some convenience variables
  fiscal_year = doc['ImlsExport']['FiscalYear']['@year']
  now = DateTime.now.strftime('%FT%H%M')
  directory = "generated/report-#{now}"
  filenames = {
      'FSR': "FSRs-FY#{fiscal_year}-#{now}.csv",
      'Project': "Projects-FY#{fiscal_year}-#{now}.csv",
  }

  states = convert_hashes doc['ImlsExport']['FiscalYear']['State']
  headers = build_header_list states

  Dir.mkdir(directory)

  filenames.each_pair do |key, filename|
    write_csv filename, headers, states, key, directory
  end

  write_state_csvs states, directory, fiscal_year, now

  if ENV['GITHUB_TOKEN']
    `tar -C #{directory} -czvf generated/SPR-FY#{fiscal_year}-#{now}.tar.gz .`
    upload_zip "SPR-FY#{fiscal_year}-#{now}.tar.gz"
  end
end

if __FILE__ == $PROGRAM_NAME
  parse_file
end
