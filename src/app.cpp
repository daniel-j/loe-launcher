
#include "app.hpp"

#include <iostream>
#include <fstream>

#include <SDL2/SDL.h>
#include <SDL2/SDL_image.h>


#include "lib/tinyfiledialogs.hpp"
#include "lib/cfgpath.hpp"

#include "image.hpp"
#include "button.hpp"

#include "aria2.hpp"

#define WINDOW_WIDTH 640
#define WINDOW_HEIGHT 360
#define APP_NAME "loelauncher"

#define MAX(x, y) (((x) > (y)) ? (x) : (y))
#define MIN(x, y) (((x) < (y)) ? (x) : (y))

// std::mutex ariamutex;
// aria2::Session* session;
float progress = 0.0;
// bool stoparia = false;

char configpath[MAX_PATH];
char default_gamedir[MAX_PATH];
char cache_path[MAX_PATH];

App::App() {
  // downloaderThread_(this::downloadThread, std::ref(jobq_), std::ref(notifyq_))
}

App::~App() {
  if (renderer) SDL_DestroyRenderer(renderer);
  if (mainWindow) SDL_DestroyWindow(mainWindow);

  IMG_Quit();
  SDL_Quit();
}
int App::run() {
  downloader.begin();

  get_user_config_folder(configpath, MAX_PATH, APP_NAME);
  get_user_data_folder(default_gamedir, MAX_PATH, "LoE");
  get_user_cache_folder(cache_path, MAX_PATH, APP_NAME);

  std::cout << "Config directory: " << configpath << std::endl;
  std::cout << "Default game directory: " << default_gamedir << std::endl;

  configfile = std::string(configpath) + "config.json";
  std::cout << "Config file: " << configfile << std::endl;

  // Default config
  config["game_dir"] = default_gamedir;
  config["game_version"] = "";

  try {
    std::ifstream f(configfile);
    json j;
    f >> j;
    config.patch(j);
  } catch (const std::invalid_argument err) {}

  saveConfig();

  SDL_Init(SDL_INIT_VIDEO);
  IMG_Init(IMG_INIT_PNG);

  mainWindow = SDL_CreateWindow(
    "Legends of Equestria Launcher",  // window title
    SDL_WINDOWPOS_CENTERED,           // initial x position
    SDL_WINDOWPOS_CENTERED,           // initial y position
    WINDOW_WIDTH,                     // width, in pixels
    WINDOW_HEIGHT,                    // height, in pixels
    SDL_WINDOW_SHOWN);

  SDL_Surface* icon = IMG_Load("assets/icon.png");
  SDL_SetWindowIcon(mainWindow, icon);
  SDL_FreeSurface(icon);

  renderer = SDL_CreateRenderer(
    mainWindow,
    -1,
    SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
  SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);
  SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "best");
  SDL_SetHint(SDL_HINT_VIDEO_ALLOW_SCREENSAVER, "1");

  /*std::string path = "slides";
  for (auto & p : fs::directory_iterator(path)) {
    std::cout << p << std::endl;
  }*/

  Image bgimage(renderer, "assets/slides/cantermore.png");
  Image logo(renderer, "assets/logo.png");

  Button::texture = IMG_LoadTexture(renderer, "assets/button.png");
  if (!Button::texture) {
    std::cerr << "IMG_Load: " << IMG_GetError() << std::endl;
    // return EXIT_FAILURE;
  }

  Button button(renderer, 475, WINDOW_HEIGHT - 100);
  button.disabled = true;

  // Check that the window was successfully created
  if (mainWindow == nullptr) {
    // In the case that the window could not be made...
    std::cerr << "Could not create window: " << SDL_GetError() << std::endl;
    return EXIT_FAILURE;
  }

  SDL_RenderClear(renderer);
  SDL_RenderPresent(renderer);

  auto cpath = std::string(cache_path);
  cpath.pop_back();
  downloader.fetch(
    "https://djazz.se/nas/games/loe/versions.json", cpath, "versions.json",
    [this, &button](bool success) {
      button.disabled = false;
      std::cout << "Success: " << success << std::endl;
      if (!success) {
        tinyfd_messageBox("Error connection to update server", "Couldn't connect to update server", "ok", "warning", 1);
        std::cout << "Unable to connect to update server" << std::endl;
        return;
      }
      fetchedVersions();
    });

  bool isrunning = true;

  while (isrunning) {
    SDL_Event e;
    // Get mouse position
    int mousex, mousey;
    SDL_GetMouseState(&mousex, &mousey);
    while (SDL_PollEvent(&e)) {
      if (e.type == SDL_QUIT) {
        isrunning = false;
        break;
      } else if (e.type == SDL_MOUSEMOTION ||
                 e.type == SDL_MOUSEBUTTONDOWN ||
                 e.type == SDL_MOUSEBUTTONUP) {
        if (button.update(mousex, mousey, e.type)) {
          std::cout << "Clicked button!" << std::endl;
          /*nfdchar_t* outPath = nullptr;
          nfdresult_t result = NFD_PickFolder( nullptr, &outPath );
          if ( result == NFD_OKAY ) {
              // setGameDir(outPath);
              delete outPath;
          } else if ( result == NFD_CANCEL ) {
              puts("User pressed cancel.");
          } else {
              fprintf(stderr, "Error: %s\n", NFD_GetError() );
          }*/
          const char* path = tinyfd_selectFolderDialog(
            "Select a file",
            config["game_dir"].get<std::string>().c_str());

          if (path) {
            std::cout << "selected path: " << path << std::endl;
            config["game_dir"] = std::string(path);
            saveConfig();
          } else {
            std::cout << "No path picked!" << std::endl;
          }
          // button.disabled = true;
        }
      }
    }
    if (!isrunning) break;
    while (!downloader.notifyq.empty()) {
      auto n = downloader.notifyq.pop();
      n();
    }

    unsigned int t = SDL_GetTicks();

    SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
    SDL_RenderClear(renderer);
    bgimage.render(
      WINDOW_WIDTH / 2 - bgimage.width / 4 - mousex / 40 + WINDOW_WIDTH / 80,
      WINDOW_HEIGHT / 2 - bgimage.height / 3 - mousey / 40 + WINDOW_HEIGHT / 80,
      0.5,
      MIN(1.0, t / 2000.0));
    logo.render(10, 10, 0.7, MIN(0.8, t / 1000.0) + 0.2);

    button.render();

    if (progress > 0) {
      SDL_Rect progressbar;
      progressbar.x = 5;
      progressbar.y = WINDOW_HEIGHT - 26;
      progressbar.h = 20;
      progressbar.w = 630;
      SDL_SetRenderDrawColor(renderer, 161, 38, 141, 255);
      SDL_RenderFillRect(renderer, &progressbar);
      progressbar.x = 8;
      progressbar.y = WINDOW_HEIGHT - 23;
      progressbar.h = 14;
      progressbar.w = progress * 624.0;
      SDL_SetRenderDrawColor(renderer, 237, 60, 149, 255);
      SDL_RenderFillRect(renderer, &progressbar);
    }

    SDL_RenderPresent(renderer);
  }

  std::cout << "Closed window." << std::endl;

  // jobq_.push(std::unique_ptr<Job>(new ShutdownJob(false)));

  return EXIT_SUCCESS;
}

void App::saveConfig() {
  std::cout << "Saving config to " << configfile << std::endl << config.dump(2) << std::endl;
  std::ofstream f(configfile);
  f << config.dump(2) << std::endl;
}

void App::fetchedVersions() {
  json versions;

  std::ifstream f(std::string(cache_path) + "versions.json");
  f >> versions;
  std::cout << versions.dump(2) << std::endl;

  latestVersion = versions[
    #ifdef __linux__
      "Linux"
    #elif defined(_WIN64)
      "Win64"
    #elif defined(_WIN32)
      "Win32"
    #elif defined(__APPLE__)
      "Mac"
    #endif
  ];
}
