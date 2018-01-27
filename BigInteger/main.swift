//
//  main.swift
//  BigInteger
//
//  Created by OOPer in cooperation with shlab.jp, on 2018/1/21.
//  Copyright © 2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//

import Foundation

func fact(_ n: BigInteger) -> BigInteger {
    if n == 0 {
        return .one
    } else {
        return n * fact(n-1)
    }
}

print(fact(100)) //93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000
