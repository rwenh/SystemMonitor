package main

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"time"

	"github.com/shirou/gopsutil/v4/cpu"
	"github.com/shirou/gopsutil/v4/disk"
	"github.com/shirou/gopsutil/v4/mem"
)

const (
	Reset   = "\033[0m"
	Red     = "\033[31m"
	Green   = "\033[32m"
	Yellow  = "\033[33m"
	Blue    = "\033[34m"
	Magenta = "\033[35m"
	Cyan    = "\033[36m"
	White   = "\033[37m"
	Bold    = "\033[1m"
)

func getData() (*disk.UsageStat, []cpu.InfoStat, []float64, *mem.VirtualMemoryStat, error) {
	diskUsage, err := disk.Usage("/")
	if err != nil {
		return nil, nil, nil, nil, err
	}

	cpuInfo, err := cpu.Info()
	if err != nil {
		return nil, nil, nil, nil, err
	}

	cpuPercent, err := cpu.Percent(time.Second, false)
	if err != nil {
		return nil, nil, nil, nil, err
	}

	memoryInfo, err := mem.VirtualMemory()
	if err != nil {
		return nil, nil, nil, nil, err
	}

	return diskUsage, cpuInfo, cpuPercent, memoryInfo, nil
}

func ClearScreen() {
	if runtime.GOOS == "windows" {
		cmd := exec.Command("cmd", "/c", "cls")
		cmd.Stdout = os.Stdout
		cmd.Run()
	} else {
		cmd := exec.Command("clear")
		cmd.Stdout = os.Stdout
		cmd.Run()
	}
}

func print(diskUsage *disk.UsageStat, cpuInfo []cpu.InfoStat, cpuPercent []float64, memoryInfo *mem.VirtualMemoryStat, err error) {
	if err != nil {
		fmt.Println(err)
	}

	fmt.Printf("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\n")
	fmt.Printf("┃          %s%sSystem Monitor%s          ┃\n", Cyan, Bold, Reset)
	fmt.Printf("┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫\n")

	fmt.Printf("\033[4;0H")
	fmt.Printf("┃ %sCPU Model:%s %s", Blue, Reset, cpuInfo[0].ModelName)
	fmt.Printf("\033[4;36H")
	fmt.Printf("┃\n")

	fmt.Printf("\033[5;0H")
	fmt.Printf("┃ %sCPU Used:%s    ", Blue, Reset)
	printBar(int(cpuPercent[0]))
	fmt.Printf(" [%.2f%%]", cpuPercent[0])
	fmt.Printf("\033[5;36H")
	fmt.Printf("┃\n")

	fmt.Printf("\033[6;0H")
	fmt.Printf("┃ Disk Used:   ")
	printBar(int(diskUsage.UsedPercent))
	fmt.Printf(" [%.2f%%]", diskUsage.UsedPercent)
	fmt.Printf("\033[6;36H")
	fmt.Printf("┃\n")

	fmt.Printf("\033[7;0H")
	fmt.Printf("┃ %sMemory Used:%s ", Yellow, Reset)
	printBar(int(memoryInfo.UsedPercent))
	fmt.Printf(" [%.2f%%]", memoryInfo.UsedPercent)
	fmt.Printf("\033[7;36H")
	fmt.Printf("┃\n")

	fmt.Printf("\033[8;0H")
	fmt.Printf("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\n")

	fmt.Printf("\033[9;0H")
	time.Sleep(1 * time.Second)
}

func printBar(progress int) {
	progress = progress / 10

	for i := 0; i < progress; i++ {
		fmt.Printf("█")
	}

	for i := 0; i < 10-progress; i++ {
		fmt.Printf("░")
	}
	// progress 50 Should output █████░░░░░
}

func main() {

	for {
		diskUsage, cpuInfo, cpuPercent, memoryInfo, err := getData()
		ClearScreen()
		print(diskUsage, cpuInfo, cpuPercent, memoryInfo, err)
	}
}
