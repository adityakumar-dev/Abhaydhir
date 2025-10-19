import Image from 'next/image';

const Footer = () => {
  return (
    <footer className="bg-[#1B1F3B] text-white py-6 px-4">
      <div className="container mx-auto">
        {/* Logo and Text Section */}
        <div className="flex flex-col md:flex-row items-center justify-center gap-4 mb-4">
          <Image
            src="/emblem.png"
            alt="Emblem"
            width={60}
            height={60}
            className="mb-2 md:mb-0"
          />
          <div className="text-center md:text-left">
            <h2 className="text-lg md:text-xl font-semibold">राजभवन उत्तराखंड</h2>
            <h2 className="text-lg md:text-xl font-semibold">RAJBHAWAN UTTARAKHAND</h2>
          </div>
        </div>

        {/* Copyright Section */}
        <div className="text-center text-sm md:text-base space-y-2">
          <p>© 2025 All rights reserved.</p>
          <p>Government of Uttarakhand</p>
        </div>

        {/* Powered By Section */}
        <div className="mt-4 flex flex-col md:flex-row items-center justify-center gap-3">
          <p className="text-sm md:text-base">Powered by</p>
          <div className="flex flex-col md:flex-row items-center gap-2">
            <p className="text-center md:text-left text-sm md:text-base">
              Veer Madho Singh Bhandari<br className="md:hidden" />
              Uttarakhand Technical University
            </p>
            <Image
              src="/vmsb.png"
              alt="VMSB Logo"
              width={50}
              height={50}
              className="mt-2 md:mt-0"
            />
          </div>
        </div>
      </div>
    </footer>
  );
};

export default Footer;