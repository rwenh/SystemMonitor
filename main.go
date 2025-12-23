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
	Reset     = "\033[0m"
	Bold      = "\033[1m"
	Underline = "\033[4m"

	Red     = "\033[31m"
	Green   = "\033[32m"
	Yellow  = "\033[33m"
	Blue    = "\033[34m"
	Magenta = "\033[35m"
	Cyan    = "\033[36m"
	White   = "\033[37m"
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
		err := cmd.Run()
		if err != nil {
			return
		}
	} else {
		cmd := exec.Command("clear")
		cmd.Stdout = os.Stdout
		err := cmd.Run()
		if err != nil {
			return
		}
	}
}

func printValue(value string, cursorTop int, cursorLeft int, screenWidth int) {
	fmt.Printf("\033[%d;%dH%s", cursorTop, cursorLeft, value)
	fmt.Printf("\033[%d;%dH┃\n", cursorTop, screenWidth)
}

func printMenu(diskUsage *disk.UsageStat, cpuInfo []cpu.InfoStat, cpuPercent []float64, memoryInfo *mem.VirtualMemoryStat, err error) {
	if err != nil {
		fmt.Println(err)
	}

	fmt.Printf("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\n")
	fmt.Printf("┃          %s%sSystem Monitor%s          ┃\n", Cyan, Bold, Reset)
	fmt.Printf("┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫\n")

	printValue(fmt.Sprintf("┃ %sCPU Model:  %s %s", Blue, Reset, cpuInfo[0].ModelName), 4, 0, 36)

	cpuLine := fmt.Sprintf("┃ %sCPU Used:%s    %s [%.2f%%]", Blue, Reset, getProgressBar(int(cpuPercent[0]), 10), cpuPercent[0])
	printValue(cpuLine, 5, 0, 36)

	diskLine := fmt.Sprintf("┃ %sDisk Used:%s   %s [%.2f%%]", Green, Reset, getProgressBar(int(diskUsage.UsedPercent), 10), diskUsage.UsedPercent)
	printValue(diskLine, 6, 0, 36)

	memLine := fmt.Sprintf("┃ %sMemory Used:%s %s [%.2f%%]", Yellow, Reset, getProgressBar(int(memoryInfo.UsedPercent), 10), memoryInfo.UsedPercent)
	printValue(memLine, 7, 0, 36)

	fmt.Printf("\033[8;0H")
	fmt.Printf("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\n")

	fmt.Printf("\033[9;0H")
	time.Sleep(500 * time.Microsecond)
}

func getProgressBar(progress int, base int) string {
	p2 := float64(progress) / 100.0
	p3 := p2 * float64(base)
	progress = int(p3)

	bar := ""
	for i := 0; i <= progress; i++ {
		bar += "█"
	}

	for i := progress; i < base-1; i++ {
		bar += "░"
	}
	return bar
}

func main() {
	for {
		diskUsage, cpuInfo, cpuPercent, memoryInfo, err := getData()
		ClearScreen()
		printMenu(diskUsage, cpuInfo, cpuPercent, memoryInfo, err)
	}
}
