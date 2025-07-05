#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sched.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/wait.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/reboot.h>
#include <sys/sysmacros.h>

char filename_stdin[1024];
char filename_stdout[1024];
char filename_stderr[1024];
char work_dir[1024];
int  rate_num = 1;
char *exec_argv[1024];
char argv_buf[1024][1024];
char linebuf[1024];

static inline void test_begin(void)
{
    asm volatile ("ibar 64 \r\n");
}

static inline void test_end(void)
{
    asm volatile ("ibar 65 \r\n");
    asm volatile(".word 0x50000000" : : : "memory");
}

void set_stack_unlimited(void) {
    struct rlimit r;
    r.rlim_cur = RLIM_INFINITY;
    r.rlim_max = RLIM_INFINITY;
    if (setrlimit(RLIMIT_STACK, &r) < 0) {
        fprintf(stderr, "setrlimit: %s\n", strerror(errno));
    }
}

void mkdir_if_needed(const char *path) {
    struct stat st = {0};
    if (stat(path, &st) == -1) {
        if (mkdir(path, 0777)) {
            fprintf(stderr, "mkdir: %s\n", strerror(errno));
        }
    }
}

void mount_special(const char *path, const char *fs) {
    fprintf(stderr, "mount %s\n", path);
    mkdir_if_needed(path);
    if (0 != mount("none", path, fs, 0, "")) {
        fprintf(stderr, "mount: %s\n", strerror(errno));
    }
}

int redirect_fd(const char *path, int fd, int output) {
    int flags = output ? O_WRONLY|O_CREAT|O_TRUNC : O_RDONLY;
    int redir_fd = open(path, flags);
    if (redir_fd < 0) {
        fprintf(stderr, "open: %s\n", strerror(errno));
        return -1;
    }
    if (dup2(redir_fd, fd) < 0) {
        fprintf(stderr, "dup2: %s\n", strerror(errno));
        return -1;
    }
    close(redir_fd);
    return 0;
}

void show_file_content(const char *path) {
    FILE *file = fopen(path, "r");
    if (file == NULL) {
        fprintf(stderr, "Error opening file: %s\n", path);
        return;
    }

    fprintf(stderr, "show  file content: %s\n", path);

    while (fgets(linebuf, sizeof(linebuf), file) != NULL) {
        fputs(linebuf, stderr);
    }

    fclose(file);
}

pid_t invoke(int copy_id)
{
    pid_t pid = fork();
    char cwd[1024];

    if (pid < 0) {
        fprintf(stderr, "fork: %s\n", strerror(errno));
    }

    if (pid != 0) {
        // in parent
        return pid;
    }

    // in child

    sprintf(cwd, "%s.%d", work_dir, copy_id);
    //fprintf(stderr, "chdir to %s\n", cwd);
    if (chdir(cwd) < 0) {
        fprintf(stderr, "chdir: %s\n", strerror(errno));
        exit(-1);
    }

    //fprintf(stderr, "set affinity\n");
    cpu_set_t set;
    CPU_ZERO(&set);
    CPU_SET(copy_id, &set);
    if (sched_setaffinity(0, sizeof(set), &set) == -1) {
        fprintf(stderr, "sched_setaffinity: %s\n", strerror(errno));
        exit(-1);
    }

    //fprintf(stderr, "set priority\n");
    errno = 0;
    if (nice(-20) < 0 && errno) {
        fprintf(stderr, "nice: %s\n", strerror(errno));
        exit(-1);
    }

    //fprintf(stderr, "redirect stdin\n");
    if (filename_stdin[0] && redirect_fd(filename_stdin, STDIN_FILENO, 0) < 0) {
        exit(-1);
    }

    //fprintf(stderr, "redirect stdout\n");
    if (filename_stdout[0] && redirect_fd(filename_stdout, STDOUT_FILENO, 1) < 0) {
        exit(-1);
    }

    //fprintf(stderr, "redirect stderr\n");
    if (filename_stderr[0] && redirect_fd(filename_stderr, STDERR_FILENO, 1) < 0) {
        exit(-1);
    }

    //fprintf(stderr, "execv\n");
    test_begin();
    execv(exec_argv[0], exec_argv);

    // an error has occurred if execv returns
    fprintf(stderr, "execv: %s\n", strerror(errno));
    exit(-1);
}

int test_main(int argc, char *argv[])
{
    FILE* f = fopen("init.cmd", "r");
    if (!f) {
        fprintf(stderr, "open init.cmd: %s\n", strerror(errno));
        return -1;
    }

    int argv_count = 0;
    char c[1024];
    while (fscanf(f, "%s", c) == 1) {
        if (c[0] == 'i') {
            fscanf(f, "%s", filename_stdin);
            fprintf(stderr, "stdin: %s\n", filename_stdin);
        } else if (c[0] == 'o') {
            fscanf(f, "%s", filename_stdout);
            fprintf(stderr, "stdout: %s\n", filename_stdout);
        } else if (c[0] == 'e') {
            fscanf(f, "%s", filename_stderr);
            fprintf(stderr, "stderr: %s\n", filename_stderr);
        } else if (c[0] == 'd') {
            fscanf(f, "%s", work_dir);
        } else if (c[0] == 'c') {
            while (fscanf(f, "%s", argv_buf[argv_count]) == 1) {
                fprintf(stderr, "argv[%d]: %s\n", argv_count, argv_buf[argv_count]);
                exec_argv[argv_count] = argv_buf[argv_count];
                argv_count ++;
            }
            break;
        }else if (c[0] == 'r') {
            fscanf(f, "%d", &rate_num);
            fprintf(stderr, "rate_num: %d\n", rate_num);
        } else {
            fprintf(stderr, "unsupported %s\n", c);
            return -1;
        }
    }

    mount_special("/proc", "proc");
    mount_special("/sys", "sysfs");
    mount_special("/dev", "devtmpfs");
    set_stack_unlimited();

    struct timeval t_begin, t_end;
    gettimeofday(&t_begin, NULL);

    pid_t pid;
    for(int idx=0; idx<rate_num; idx++){
        if ((pid = invoke(idx)) < 0) {
            // child error
            return -1;
        } else {
            fprintf(stderr, "Invoking copy of %d, id = %d\n", idx, pid);
        }
    }

    /************ Waiting for all the copies finishing *********/
    int active_copies = rate_num;
    int status;
    while(active_copies){
        pid = wait(&status);
        if (WIFEXITED(status)) {
            int exit_status = WEXITSTATUS(status);
            fprintf(stderr, "Child %d Exit status was %d\n", pid, exit_status);
            if (exit_status)
                return -1;
        } else if(WIFSIGNALED(status)){
            fprintf(stderr, "Child %d Exit with signal:%d\n", pid, WTERMSIG(status));
            return -1;
        } else {
            fprintf(stderr, "Child %d what happened?\n", pid);
            return -1;
        }
        active_copies--;
    }

    gettimeofday(&t_end, NULL);
    unsigned int time = t_end.tv_sec - t_begin.tv_sec;
    fprintf(stderr, "Total time: %us\n", time);

    return 0;
}

void fix_dev_console() {
    struct stat st;
    if (stat("/dev/console", &st) != 0) {
        perror("[INIT] stat /dev/console failed");
        return;
    }

    if (!S_ISCHR(st.st_mode) || major(st.st_rdev) != 5 || minor(st.st_rdev) != 1) {
        // printf("[INIT] Replacing fake /dev/console...\n");
        if (unlink("/dev/console") != 0) {
            perror("[INIT] unlink /dev/console failed");
            return;
        }
        if (mknod("/dev/console", S_IFCHR | 0600, makedev(5, 1)) != 0) {
            perror("[INIT] mknod /dev/console failed");
            return;
        }
        // printf("[INIT] Created real /dev/console\n");
    } else {
        // printf("[INIT] /dev/console is already correct\n");
    }

    int fd = open("/dev/console", O_RDWR);
    if (fd < 0) {
        perror("[INIT] open /dev/console failed");
        return;
    }

    dup2(fd, STDIN_FILENO);
    dup2(fd, STDOUT_FILENO);
    dup2(fd, STDERR_FILENO);

    if (fd > 2) close(fd);
    // printf("[INIT] /dev/console reattached to stdin/stdout/stderr\n");
}

int main(int argc, char *argv[])
{
    int res;

    fix_dev_console();

    stderr = fdopen(dup(STDERR_FILENO), "w");
    res = test_main(argc, argv);

    // for (int idx = 0; idx < rate_num; idx++) {
    //     char filepath[1024];
    //     sprintf(filepath, "%s.%d/%s", work_dir, idx, filename_stdout);
    //     show_file_content(filepath);
    //     sprintf(filepath, "%s.%d/%s", work_dir, idx, filename_stderr);
    //     show_file_content(filepath);
    // }

    fprintf(stderr, "%s\n", res ? "xxyyzz-FAILURE" : "xxyyzz-SUCCESS");
    fflush(NULL);
    test_end();

    sleep(1);
    reboot(RB_POWER_OFF);
    return 0;
}
