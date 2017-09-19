
#include <iostream>
// #include <chrono>

//#include <experimental/filesystem>
#include <algorithm>
#include <math.h>
#include <SDL2/SDL.h>
#include <SDL2/SDL_image.h>
#include <aria2/aria2.h>
#include <nfd.h>

#define WINDOW_WIDTH 640
#define WINDOW_HEIGHT 360

//namespace fs = std::experimental::filesystem;

SDL_mutex* arialock;
aria2::Session* session;
float progress = 0.0;
bool stoparia = false;

int downloadEventCallback(aria2::Session* session, aria2::DownloadEvent event, aria2::A2Gid gid, void* userData) {
  switch (event) {
  case aria2::EVENT_ON_DOWNLOAD_COMPLETE:
    std::cerr << "COMPLETE";
    break;
  case aria2::EVENT_ON_DOWNLOAD_ERROR:
    std::cerr << "ERROR";
    break;
  default:
    return 0;
  }
  std::cerr << " [" << aria2::gidToHex(gid) << "] ";
  aria2::DownloadHandle* dh = aria2::getDownloadHandle(session, gid);
  if (!dh)
    return 0;
  if (dh->getNumFiles() > 0) {
    aria2::FileData f = dh->getFile(1);
    // Path may be empty if the file name has not been determined yet.
    if (f.path.empty()) {
      if (!f.uris.empty()) {
        std::cerr << f.uris[0].uri;
      }
    }
    else {
      std::cerr << f.path;
    }
  }
  aria2::deleteDownloadHandle(dh);
  std::cerr << std::endl;
  return 0;
}

int AriaThread(void *data) {
  int rv;

  SDL_LockMutex(arialock);
  aria2::libraryInit();
  // session is actually singleton: 1 session per process
  // Create default configuration. The libaria2 takes care of signal
  // handling.
  aria2::SessionConfig config;
  // Add event callback
  config.downloadEventCallback = downloadEventCallback;
  aria2::KeyVals opts;
  opts.push_back(aria2::KeyVals::value_type("no-conf", "true"));
  opts.push_back(aria2::KeyVals::value_type("check-integrity", "true"));
  opts.push_back(aria2::KeyVals::value_type("seed-time", "0"));
  opts.push_back(aria2::KeyVals::value_type("dir", "dl"));
  session = aria2::sessionNew(opts, config);
  
  // Add download item to session

  aria2::KeyVals options;
  rv = aria2::addTorrent(session, nullptr, (char*)data, options);
  if (rv < 0) {
    SDL_UnlockMutex(arialock);
    std::cerr << "Failed to add download " << (char*)data << std::endl;
    return 1;
  }
  SDL_UnlockMutex(arialock);

  // auto start = std::chrono::steady_clock::now();
  for (;;) {
    if (SDL_LockMutex(arialock) != 0) {
      fprintf(stderr, "Couldn't lock mutex\n");
      break;
    }
    if (session == nullptr || stoparia) {
      SDL_UnlockMutex(arialock);
      break;
    }
    rv = aria2::run(session, aria2::RUN_ONCE);
    if (rv != 1) {
      SDL_UnlockMutex(arialock);
      break;
    }

    std::vector<aria2::A2Gid> gids = aria2::getActiveDownload(session);

    if (gids.size() > 0) {
      aria2::DownloadHandle* dh = aria2::getDownloadHandle(session, gids[0]);
      progress = 1.0f * dh->getCompletedLength() / dh->getTotalLength();
      aria2::deleteDownloadHandle(dh);
      // printf("%f\n", progress * 100);
    }

    /*
    auto now = std::chrono::steady_clock::now();
    auto count =
        std::chrono::duration_cast<std::chrono::milliseconds>(now - start).count();
    aria2::GlobalStat gstat = aria2::getGlobalStat(session);
    std::vector<aria2::A2Gid> gids = aria2::getActiveDownload(session);

    // Print progress information once per 500ms
    if (count >= 500) {
      start = now;
      std::cerr << "Overall #Active:" << gstat.numActive
                << " #waiting:" << gstat.numWaiting
                << " D:" << gstat.downloadSpeed / 1024 << "KiB/s"
                << " U:" << gstat.uploadSpeed / 1024 << "KiB/s " << std::endl;
      
      for (const auto& gid : gids) {
        aria2::DownloadHandle* dh = aria2::getDownloadHandle(session, gid);
        if (dh) {
          std::cerr << "    [" << aria2::gidToHex(gid) << "] "
                    << dh->getCompletedLength() << "/" << dh->getTotalLength()
                    << "(" << (dh->getTotalLength() > 0
                                   ? (100 * dh->getCompletedLength() /
                                      dh->getTotalLength())
                                   : 0)
                    << "%)"
                    << " D:" << dh->getDownloadSpeed() / 1024
                    << "KiB/s, U:" << dh->getUploadSpeed() / 1024 << "KiB/s"
                    << std::endl;
          aria2::deleteDownloadHandle(dh);
        }
      }
    }
    */
    SDL_UnlockMutex(arialock);
  }

  if (SDL_LockMutex(arialock) != 0) {
    rv = aria2::sessionFinal(session);
    aria2::libraryDeinit();
    SDL_UnlockMutex(arialock);
  }

  return rv;
}

class Button {
private:
  SDL_Rect src;
  SDL_Renderer* r;
  bool hovering = false;
  bool isclicking = false;
public:
  static SDL_Texture* texture;
  SDL_Rect position;
  bool disabled = false;

  Button(SDL_Renderer* renderer, int x = 0, int y = 0) {
    r = renderer;
    src.x = 0;
    src.y = 0;
    src.w = 160;
    src.h = 60;
    position.x = x;
    position.y = y;
    position.w = src.w;
    position.h = src.h;
  }
  ~Button() {}
  void render() {
    src.y = (disabled ? 2 : (hovering ? 1 : 0)) * 60;
    // if (disabled) return;
    SDL_RenderCopy(r, Button::texture, &src, &position);
  }
  bool update(int x, int y, Uint32 type) {
    hovering = (x >= position.x && x < position.x + position.w) && (y >= position.y && y < position.y + position.h);
    if (type == SDL_MOUSEBUTTONDOWN && hovering) {
      isclicking = true;
    } else if (type == SDL_MOUSEMOTION && !hovering) {
      isclicking = false;
    } else if (type == SDL_MOUSEBUTTONUP && hovering && isclicking && !disabled) {
      isclicking = false;
      return true;
    }
    return false;
  }
};
SDL_Texture* Button::texture = nullptr;

class Image {
private:
  SDL_Rect dst;
  SDL_Renderer* r;
  SDL_Texture* texture = nullptr;
public:
  int width = 0;
  int height = 0;
  Image(SDL_Renderer* renderer, const char* imagepath) {
    r = renderer;
    texture = IMG_LoadTexture(r, imagepath);
    if (!texture) {
      printf("IMG_Load: %s\n", IMG_GetError());
      // handle error
    }
    SDL_QueryTexture(texture, nullptr, nullptr, &width, &height);
  }
  ~Image() {
    SDL_DestroyTexture(texture);
  }
  void render(int x, int y, float scale = 1.0, float alpha = 1.0) {
    dst.x = x;// - (width * scale - width) / 2.0;
    dst.y = y;// - (height * scale - height) / 2.0;
    dst.w = width;// * scale;
    dst.h = height;// * scale;
    // printf("%dx%d %dx%d with scale %f to %dx%d\n", x, y, width, height, scale, dst.x, dst.y);
    SDL_RenderSetScale(r, scale, scale);
    SDL_SetTextureAlphaMod(texture, 255 * alpha);
    SDL_RenderCopy(r, texture, NULL, &dst);
    SDL_RenderSetScale(r, 1.0, 1.0);
  }
};

int main(int argc, char** argv) {

  SDL_Init(SDL_INIT_VIDEO);
  IMG_Init(IMG_INIT_PNG);

  SDL_Window* window = SDL_CreateWindow(
    "Legends of Equestria Launcher",  // window title
    SDL_WINDOWPOS_CENTERED,           // initial x position
    SDL_WINDOWPOS_CENTERED,           // initial y position
    WINDOW_WIDTH,                     // width, in pixels
    WINDOW_HEIGHT,                    // height, in pixels
    SDL_WINDOW_ALLOW_HIGHDPI | SDL_WINDOW_SHOWN
  );

  SDL_Surface* icon = IMG_Load("assets/icon.png");
  SDL_SetWindowIcon(window, icon);
  SDL_FreeSurface(icon);

  SDL_Renderer* renderer = SDL_CreateRenderer(
    window,
    -1,
    SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC
  );
  SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);
  SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "best");

  /*std::string path = "slides";
  for (auto & p : fs::directory_iterator(path)) {
    std::cout << p << std::endl;
  }*/

  Image bgimage(renderer, "assets/slides/cantermore.png");
  Image logo(renderer, "assets/logo.png");

  Button::texture = IMG_LoadTexture(renderer, "assets/button.png");
  if (!Button::texture) {
    printf("IMG_Load: %s\n", IMG_GetError());
    // return EXIT_FAILURE;
  }

  Button button(renderer, 475, WINDOW_HEIGHT - 100);

  // Check that the window was successfully created
  if (window == nullptr) {
    // In the case that the window could not be made...
    printf("Could not create window: %s\n", SDL_GetError());
    return EXIT_FAILURE;
  }

  SDL_RenderClear(renderer);
  SDL_RenderPresent(renderer);

  arialock = SDL_CreateMutex();
  // SDL_Thread* thread = SDL_CreateThread(AriaThread, "AriaThread", (void*)"loe.torrent");

  bool isrunning = true;

  while (isrunning) {
    SDL_Event e;
    //Get mouse position
    int mousex, mousey;
    SDL_GetMouseState(&mousex, &mousey);
    while (SDL_PollEvent(&e)) {
      if (e.type == SDL_QUIT) {
        isrunning = false;
        break;
      } else if (e.type == SDL_MOUSEMOTION || e.type == SDL_MOUSEBUTTONDOWN || e.type == SDL_MOUSEBUTTONUP) {
        if (button.update(mousex, mousey, e.type)) {
          printf("Clicked button!\n");
          nfdchar_t* outPath = nullptr;
          nfdresult_t result = NFD_PickFolder( nullptr, &outPath );
          if ( result == NFD_OKAY ) {
              // setGameDir(outPath);
              delete outPath;
          } else if ( result == NFD_CANCEL ) {
              puts("User pressed cancel.");
          } else {
              fprintf(stderr, "Error: %s\n", NFD_GetError() );
          }
          // button.disabled = true;
        }
      }
    }
    if (!isrunning) break;

    unsigned int t = SDL_GetTicks();

    SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
    SDL_RenderClear(renderer);
    bgimage.render(
      WINDOW_WIDTH / 2 - bgimage.width / 4 - mousex / 40 + WINDOW_WIDTH / 80,
      WINDOW_HEIGHT / 2 - bgimage.height / 3 - mousey / 40 + WINDOW_HEIGHT / 80, 
      0.5,
      std::min(1.0, t / 2000.0)
    );
    logo.render(10, 10, 0.7, std::min(0.8, t / 1000.0) + 0.2);
    
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

  printf("Closed window\n");

  SDL_DestroyTexture(Button::texture);
  SDL_DestroyRenderer(renderer);
  SDL_DestroyWindow(window);
  stoparia = true;
  // SDL_WaitThread(thread, NULL);
  SDL_DestroyMutex(arialock);

  IMG_Quit();
  SDL_Quit();

  return EXIT_SUCCESS;
}

// To make it build on Windows
int WinMain() {
  return main(0, nullptr);
}
