class ProjectGiamSatKPILists {
  static final List<String> alwaysFullNhanSuProjects = [
    'Sân bay nội bài ga T2',
    'Ga T2 SBDN',
  ];

  static final List<String> sharedHighestNhanSuProjects = [
    'Công ty liên doanh tháp ngân hàng đầu tư và phát triển Việt Nam (BIDV) - 194 Trần Quang Khải',
    'Bệnh viện Việt Đức',
    '',
  ];

  static bool isAlwaysFullNhanSu(String project) {
    return alwaysFullNhanSuProjects.contains(project);
  }

  static bool isSharedHighestNhanSu(String project) {
    return sharedHighestNhanSuProjects.contains(project);
  }
}