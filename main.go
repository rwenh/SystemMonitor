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

	fmt.Println("┏━━━━━━━━━━━━━━━━━━━━━━━━┓\n┃      System Monitor    ┃\n┣━━━━━━━━━━━━━━━━━━━━━━━━┫\n")

	fmt.Printf("\033[4;0H")
	fmt.Println("┃ CPU Model:", cpuInfo[0].ModelName)
	fmt.Printf("\033[4;26H")
	fmt.Printf("┃\n")

	fmt.Printf("\033[5;0H")
	fmt.Printf("┃ CPU Usage: %.2f%%\n", cpuPercent[0])
	fmt.Printf("\033[5;26H")
	fmt.Printf("┃\n")

	fmt.Printf("\033[6;0H")
	fmt.Printf("┃ Disk Used: %.2f%%\n", diskUsage.UsedPercent)
	fmt.Printf("\033[6;26H")
	fmt.Printf("┃\n")

	fmt.Printf("\033[7;0H")
	fmt.Printf("┃ Memory Used: %.2f%%\n", memoryInfo.UsedPercent)
	fmt.Printf("\033[7;26H")
	fmt.Printf("┃\n")

	fmt.Printf("\033[8;0H")
	fmt.Printf("┗━━━━━━━━━━━━━━━━━━━━━━━━┛")

	time.Sleep(2 * time.Second)
}

func main() {

	for {
		diskUsage, cpuInfo, cpuPercent, memoryInfo, err := getData()
		ClearScreen()
		print(diskUsage, cpuInfo, cpuPercent, memoryInfo, err)
	}

}
