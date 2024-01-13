'use client'

import Image from 'next/image'

import { PrimaryButton } from '@/components/ui/button'

export default function Payment() {
  const onClickPay = () => {
    console.log('open payment')
  }
  return (
    <div className="flex items-center justify-center h-screen">
      <GhoButton onClick={onClickPay} />
    </div>
  )
}

type GhoButtonProps = {
  onClick: () => void
}
function GhoButton({ onClick }: GhoButtonProps) {
  return (
    <PrimaryButton size={'lg'} onClick={onClick}>
      <div className="flex items-center gap-2">
        <Image
          src="/assets/icon-light.svg"
          width={36}
          height={36}
          alt="GHO icon"
        />
        <p>Pay with GHO</p>
      </div>
    </PrimaryButton>
  )
}
