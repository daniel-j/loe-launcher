
#ifndef LOE_APP_H
#define LOE_APP_H

#include <thread>
#include <SDL2/SDL.h>

#include "lib/json.hpp"
#include "aria2.hpp"

using json = nlohmann::json;

class App {
 private:
  Downloader downloader;
  SDL_Window* mainWindow = nullptr;
  SDL_Renderer* renderer = nullptr;
  std::string configfile;
	json config;
  std::string latestVersion = "";
  std::string latestLauncher = "";
 public:
  App();
  ~App();
  int run();
  void saveConfig();
  void fetchedVersions();
};

#endif
