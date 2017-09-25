
#ifndef LOE_ARIA2_H
#define LOE_ARIA2_H

#include <iostream>
#include <chrono>
#include <thread>
#include <mutex>
#include <queue>
#include <aria2/aria2.h>

class App;

// This struct is used to report download progress for active
// downloads from downloader thread to UI thread.
struct DownloadStatus {
  aria2::A2Gid gid;
  int64_t totalLength;
  int64_t completedLength;
  int downloadSpeed;
  int uploadSpeed;
  std::string filename;
};

template <typename T> std::string abbrevsize(T size);

// std::queue<T> wrapper synchronized by mutex. In this example
// program, only one thread consumes from the queue, so separating
// empty() and pop() is not a problem.
template <typename T> class SynchronizedQueue {
 private:
  std::queue<std::unique_ptr<T>> q_;
  std::mutex m_;

 public:
  SynchronizedQueue() {};
  ~SynchronizedQueue() {};
  void push(std::unique_ptr<T>&& t) {
    std::lock_guard<std::mutex> l(m_);
    q_.push(std::move(t));
  }
  std::unique_ptr<T> pop() {
    std::lock_guard<std::mutex> l(m_);
    std::unique_ptr<T> t = std::move(q_.front());
    q_.pop();
    return t;
  }
  bool empty() {
    std::lock_guard<std::mutex> l(m_);
    return q_.empty();
  }
};

class Job {
 public:
  virtual ~Job(){};
  virtual void execute(aria2::Session* session) = 0;
};

// Interface to report back to UI thread from downloader thread
struct Notification {
  virtual ~Notification(){};
  Notification(unsigned int type, void* data) : type(type), data(data) {};
  unsigned int type;
  void* data;
};

enum Notifications {
  DownloadEventNotification
};

struct DownloadEvent {
  aria2::DownloadEvent event;
  aria2::A2Gid gid;
};

typedef SynchronizedQueue<Job> JobQueue;
typedef SynchronizedQueue<Notification> NotifyQueue;

// Job to shutdown downloader thread
class ShutdownJob : public Job {
 public:
  ShutdownJob(bool force) : force(force) {}
  virtual void execute(aria2::Session* session) {
    aria2::shutdown(session, force);
  }
  bool force;
};
/*
class DownloadEventNotification : public Notification {
 public:
  DownloadEventNotification(aria2::DownloadEvent event, aria2::A2Gid gid) : event(event), gid(gid) {}
  virtual void notify(App* app);
  aria2::DownloadEvent event;
  aria2::A2Gid gid;
};

class DownloadStatusNotification : public Notification {
 public:
  DownloadStatusNotification(std::vector<DownloadStatus>&& v) : v(v) {}
  virtual void notify(App* app) {
    for (auto& a : v) {
      std::cout << "[" << aria2::gidToHex(a.gid) << "] "
           << abbrevsize(a.completedLength) << "/"
           << abbrevsize(a.totalLength) << "("
           << (a.totalLength != 0 ? a.completedLength * 100 / a.totalLength : 0)
           << "%)" << " D:" << abbrevsize(a.downloadSpeed)
           << " U:" << abbrevsize(a.uploadSpeed) << std::endl
           << "File:" << a.filename << std::endl;
    }
  }
  std::vector<DownloadStatus> v;
};

class ShutdownNotification : public Notification {
 public:
  ShutdownNotification() {}
  virtual void notify(App* app) {}
};
*/

// Job to send URI to download and options to downloader thread
class AddUriJob : public Job {
 public:
  AddUriJob(std::vector<std::string>&& uris, aria2::KeyVals&& options, aria2::A2Gid* g)
      : uris(uris), options(options) {
        gid = g;
      }
  virtual void execute(aria2::Session* session) {
    int rv = aria2::addUri(session, gid, uris, options);
    if (rv != 0) {
      std::cerr << "aria2: Failed to add uri " << uris[0] << std::endl;
      return;
    } else {
      std::cout << aria2::gidToHex(*gid) << std::endl;
    }
  }
  std::vector<std::string> uris;
  aria2::KeyVals options;
  aria2::A2Gid* gid;
};

int ariaWorker(JobQueue& jobq, NotifyQueue& notifyq);

#endif
