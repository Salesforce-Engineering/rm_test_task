public with sharing class EVE_UserService implements EVE_IService{		
	public static final String SYS_ADMIN_PROFILE = ProfilesConfig__mdt.getInstance('SystemAdministrator').ProfileName__c;
	public static final String SYS_ADMIN_API_PROFILE = ProfilesConfig__mdt.getInstance('SystemAdministratorAPIonly').ProfileName__c;
	public static final String ESB_PROFILE = ProfilesConfig__mdt.getInstance('EnterpriseServiceBus').ProfileName__c;	
	public static final String REPORTING_PROFILE = ProfilesConfig__mdt.getInstance('ReportingSpecialist').ProfileName__c;
	public static final String OP_PROFILE = ProfilesConfig__mdt.getInstance('OrderProcessing').ProfileName__c;
	public static final String SDR_PROFILE = ProfilesConfig__mdt.getInstance('SDR').ProfileName__c;
	public static final String RENEWALS_MANAGER_PROFILE = ProfilesConfig__mdt.getInstance('RenewalsManager').ProfileName__c;
	public static final String RENEWALS_PROFILE = getProfileFromConfig('OppProductDeletion__c');
	public static final Set<String> ADMIN_PROFILES = new Set<String> { SYS_ADMIN_PROFILE };

	//to be updated
	//only used for last mod by sales date on task, to be replaced to align with logic for workflows - SF-9950.
	//originates from SF-7645 - updates date if current profile CONTAINS this value (isSalesProfile)
	public static final Set<String> SALES_PROFILE_TASK = new Set<String>{'Sales'};

	public static final String SFDC_AUTOMATION_USER_NAME = 'SFDCAutomation';
	public static final String SFDC_AUTOMATION_ANOTHER_USER_NAME = 'exsfdcautomation';

	private static EVE_UserRepository userRepository = new EVE_UserRepository();

	private static Map<Id, User> adminUsers = null;
	private static Map<Id, User> dqUsers = null;
	private static Map<String, Profile> userProfiles = null;
	private static ProfilesConfig__mdt[] profilesConfig;
	public static Profile currentProfile;	
	@TestVisible
	private Boolean isLightningThemeDisplayed = UserInfo.getUiThemeDisplayed() == 'Theme4d';

	public EVE_UserService() {
	}

	public static Profile getCurrentProfile() {
		if (currentProfile == null) {
			if (isAutomatedProcessUser()) {
				//automated user profile can not be queried
				//pretend sys admin runs code
				currentProfile = new Profile(Name = SYS_ADMIN_PROFILE);
			} else {
				currentProfile = [
					SELECT Id, Name
					FROM Profile
					WHERE Id = :UserInfo.getProfileId()
				];
			}
		}

		return currentProfile;
	}

	public static Map<Id, Profile> getProfiles(String[] profilesNames) {
		if (userProfiles == null) {
			userProfiles = new Map<String, Profile>([SELECT Id, Name FROM Profile where Name in :profilesNames]);
		}

		Map<Id, Profile> profilesToReturn = new Map<Id, Profile>();
		for (String profileName : profilesNames) {
			Profile profile = userProfiles.get(profileName);
			if (profile != null) {
				profilesToReturn.put(profile.Id, profile);
			}
		}

		return profilesToReturn;
	}

	public static Map<Id, Profile> getAdminProfiles() {
		return getProfiles(new String[]{ SYS_ADMIN_PROFILE });
	}

	private static Map<Id, User> getAdminUsers() {
		if (adminUsers == null) {
			adminUsers = new Map<Id, User> ([SELECT Id FROM User WHERE Profile.Name IN :ADMIN_PROFILES]);
		}
		return adminUsers;
	}

	public static Boolean isAdmin() {
		return getAdminUsers().containsKey(UserInfo.getUserId());
	}
	
	private static Map<Id, User> getDQUsers() {
		if (dqUsers == null) {
			dqUsers = new Map<Id, User>(userRepository.getDQUsers());
		}
		return dqUsers;
	}

	public static Boolean isDQ() {
		return getDQUsers().containsKey(UserInfo.getUserId());
	}

	public Map<Id, User> getUsers(Id[] userIds){
		return userRepository.getUsers(userIds);
	}

	public User getCurrentUser() {
		return userRepository.getUser(UserInfo.getUserId());
	}

	//only used for last mod by sales date on task, to be replaced to align with logic for workflows - SF-9950.
	//originates from SF-7645 - updates date if current profile CONTAINS this value (isSalesProfile)
	public static Boolean isSalesProfile() {
		Profile selectedProfile = getCurrentProfile();
		if (selectedProfile != null) {
			//return SALES_PROFILE.contains(getCurrentProfile().Name);
			string profileName = selectedProfile.Name;
			for (string searchString : SALES_PROFILE_TASK) {
				if (profileName.contains(searchString)) {
					return true;
				}
			}
		} 
		return false;
	}

	public Boolean isUserUnderLightning() {
		return isLightningThemeDisplayed ||
				(userRepository.getLightningExperiencePermission(UserInfo.getUserId()) &&
				userRepository.isLightningPreferredByUser(UserInfo.getUserId()));
	}
	
    public Boolean isUserHasPermissionSet(String permissionSetName) {
		PermissionSet ps = userRepository.getPermissionSetByName(permissionSetName);
		if (ps == null) {
			return false;
		}
		PermissionSetAssignment[] assignments = userRepository.getPermissionSetAssignments(ps.Id, UserInfo.getUserId());
		return assignments.size() > 0;
	}

	public Boolean isProfile(String profileName) {
		return getCurrentProfile().Name == profileName;
	}

	public Boolean isProfile(Set<String> profileNames) {
		Profile p = getCurrentProfile();
		for (String name : profileNames) {
			if (p.Name == name) {
				return true;
			}
		}
		return false;
	}

	public String getProdOrgId() {
		return ProdOrgID__c.getOrgDefaults().ProdOrgID18Char__c;
	}

	public Boolean isProd() {
		return UserInfo.getOrganizationId() == getProdOrgId();
	}

	public static String getProfileForTestSalesUser() {
		return ProfilesConfig__mdt.getInstance('SalesRep').ProfileName__c;
	}

	public static String getProfileForTestSalesManagerUser() {
		return ProfilesConfig__mdt.getInstance('SalesManager').ProfileName__c;
	}

	public static String getProfileForTestSalesDirectorUser() {
		return ProfilesConfig__mdt.getInstance('SalesDirector').ProfileName__c;
	}

	public static String getProfileFromConfig(String FieldName) {
		String profile = '';
		Set<String> profiles = getProfilesFromConfig(FieldName);
		if (profiles?.size() > 0) {
			profile = new List<String>(profiles).get(0);
		}
		return profile;
	}

	public static Set<String> getProfilesFromConfig(String FieldName) {
		Set<String> profiles = new Set<String>();
		if (profilesConfig == null) {
			profilesConfig = ProfilesConfig__mdt.getAll().values();
		}
		for (ProfilesConfig__mdt p : profilesConfig) {
			if (String.isBlank(FieldName) || p.get(FieldName) == true) {
				profiles.add(p.ProfileName__c);
			}
		}
        return profiles;
	}

	public static String getQuickOppTypesFromConfig(String OppType) {
		Profile p = getCurrentProfile();
		String activityTypes = ''; 
		if (profilesConfig == null) {
			profilesConfig = ProfilesConfig__mdt.getAll().values();
		}
		for (ProfilesConfig__mdt pc : profilesConfig) {
			if (p.Name == pc.ProfileName__c) {
				activityTypes = OppType == 'Maintenance' ?	
											pc.OppQuickUpdateTypesMaintenance__c : 
											pc.OppQuickUpdateTypesStandard__c;
			}
		}
        return activityTypes;
	}

	public static Boolean isFeatureAccessibleByProfile(String FieldName) {
		String customPermission = FieldName?.removeEnd('__c');
		return getProfilesFromConfig(FieldName).contains(getCurrentProfile().Name) || hasCustomPermission(customPermission);
	}

	public static Boolean hasCustomPermission(String permissionName) {
		return FeatureManagement.checkPermission(permissionName);
	}

	private static Boolean isAutomatedProcessUser() {
		return 'AutomatedProcess'.equalsIgnoreCase(UserInfo.getUserType());
	}
}