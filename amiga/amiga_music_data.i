; Generated native relocation/instrument/name tables.
AmigaMusicRelocations:
        dc.w 2,20,28,36,44,52,60,70,76,82,88,94
        dc.w 100,106,112,122,128,134,140,148,154,160,166,176
        dc.w 184,190,196,294,806,892,958,1348,1440,1444,1448,1452
        dc.w 1456,1460,1464,1468,1472,1476,1480,1484,1488,1492,1496,1500
        dc.w 1504,1508,2620,2624,2628,2632,2636,2640,2644,2648,2652,2656
        dc.w 2660,2664,2668,2672,2676,2680,2684,2688,2692,2696,2700,2704
        dc.w 2708,2712,2716,2720,2724,2728,3020,3376,3418,3490,3498,3506
        dc.w 3512,3520,3528,3546,3554,3562,3574,3582,3592,3598,3606,3612
        dc.w 3620,3626,3634,3640,3648,3654,3718,3784,3888,3934,4024,4032
        dc.w 4388,4424,4468,4654,4660,4668,4674,4726,4864,4928,4936,4944
        dc.w 4950,4958,4988,4998,5008,5030,5846,6130,6258,6516,6624,6684
        dc.w 6710,6716,6724,6730,6736,6790,6798,6820,6828,6836,6844,6852
        dc.w 6860,6868,6876,6892,6920,6926,6934,6942,6950,6956,6964,6972
        dc.w 6988,7004,7010,7018,7024,7030,7212,7218,7372,7564,8456,8776
        dc.w 8864,8980,9082,9090,9100,9108,9116,9124,9132,9348,9356,9364
        dc.w 9372,9378,9386
        dc.w -1
AmigaMusicDmaPatchTable:
        dc.w 256,1
        dc.w 858,0
        dc.w 1144,0
        dc.w -1,0
AmigaMusicBankOffsets:
        dc.w 0,34,68,102,136,1066,3116,4142,4176,4570,6620,6638,6648
        dc.w 0,34,68,102,136,1066,4176,4570,6620,6654,0,0,0
        dc.w 0,34,68,102,136,1066,8704,4570,6620,6648,0,0,0
        dc.w 0,34,68,102,136,1066,14986,6654,6620,6648,17518,0,0
        dc.w 0,34,68,102,136,1066,3116,6620,17536,0,0,0,0
AmigaMusicTrackBanks:
        dc.b 0,1,2,3,4,0,1,2,3,4,0,1,2,3,4
AmigaMusicTrackScores:
        dc.b 0,1,2,3,4,5,5,5,5,5,6,6,6,6,6
        EVEN
AmigaTrackNameDirectory:
        dc.l AmigaTrackName0
        dc.l AmigaTrackName1
        dc.l AmigaTrackName2
        dc.l AmigaTrackName3
        dc.l AmigaTrackName4
        dc.l AmigaTrackName5
        dc.l AmigaTrackName6
        dc.l AmigaTrackName7
        dc.l AmigaTrackName8
        dc.l AmigaTrackName9
        dc.l AmigaTrackName10
        dc.l AmigaTrackName11
        dc.l AmigaTrackName12
        dc.l AmigaTrackName13
        dc.l AmigaTrackName14
AmigaTrackName0: dc.b "AMIGA - LEVEL 1",0
AmigaTrackName1: dc.b "AMIGA - LEVEL 2",0
AmigaTrackName2: dc.b "AMIGA - LEVEL 3",0
AmigaTrackName3: dc.b "AMIGA - LEVEL 4",0
AmigaTrackName4: dc.b "AMIGA - LEVEL 5",0
AmigaTrackName5: dc.b "AMIGA - CLEAR 1",0
AmigaTrackName6: dc.b "AMIGA - CLEAR 2",0
AmigaTrackName7: dc.b "AMIGA - CLEAR 3",0
AmigaTrackName8: dc.b "AMIGA - CLEAR 4",0
AmigaTrackName9: dc.b "AMIGA - CLEAR 5",0
AmigaTrackName10: dc.b "AMIGA - GAME OVER 1",0
AmigaTrackName11: dc.b "AMIGA - GAME OVER 2",0
AmigaTrackName12: dc.b "AMIGA - GAME OVER 3",0
AmigaTrackName13: dc.b "AMIGA - GAME OVER 4",0
AmigaTrackName14: dc.b "AMIGA - GAME OVER 5",0
        EVEN
AmigaMusicCoreLZ:
        incbin "data/amiga_music_core.lz"
        EVEN
AmigaMusicSampleSource:
        incbin "data/amiga_music_samples.bin"
        EVEN
