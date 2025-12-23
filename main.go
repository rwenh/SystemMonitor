package main

import (
	"fmt"
	"log"
	"time"

	"github.com/shirou/gopsutil/v4/cpu"
	"github.com/shirou/gopsutil/v4/disk"
	"github.com/shirou/gopsutil/v4/mem"
)

func print() {
	for {
		diskUsage, err := disk.Usage("/")
		if err != nil {
			log.Fatal(err)
		}

		cpuInfo, err := cpu.Info()
		if err != nil {
			log.Fatal(err)
		}

		cpuPercent, err := cpu.Percent(time.Second, false)
		if err != nil {
			log.Fatal(err)
		}

		// Get memory info
		memoryInfo, err := mem.VirtualMemory()
		if err != nil {
			log.Fatal(err)
		}

		fmt.Println("---System Monitor---")
		fmt.Println("CPU Model:", cpuInfo[0].ModelName)
		fmt.Printf("CPU Usage: %.2f%%\n", cpuPercent[0])
		fmt.Printf("Disk Used: %.2f%%\n", diskUsage.UsedPercent)
		fmt.Printf("Memory Used: %.2f%%\n", memoryInfo.UsedPercent)

		// Wait 2 seconds before next update
		time.Sleep(2 * time.Second)
	}
}

func main() {
	print()
}
